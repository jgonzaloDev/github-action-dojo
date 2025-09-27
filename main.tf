terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.34.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# ======================
# Data Sources
# ======================
data "azurerm_subscription" "primary" {}

# ======================
# Paso 1 : Virtual Network + Subnets
# ======================
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "backend" {
  name                 = var.subnets["backend"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "sql" {
  name                 = var.subnets["sql"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "keyvault" {
  name                 = var.subnets["keyvault"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "blobstorage" {
  name                 = var.subnets["blobstorage"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_subnet" "appgw" {
  name                 = var.subnets["appgw"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.5.0/24"]
}

resource "azurerm_subnet" "privateend" {
  name                 = var.subnets["privateend"]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.6.0/24"]
}

# ======================
# SQL Server + Database
# ======================
resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_login
  administrator_login_password  = var.sql_admin_password
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "database" {
  name      = var.database_name
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}

# ======================
# App Service Plans
# ======================
resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_service_plan" "plan_web" {
  name                = var.app_service_plan_name_web
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Windows"
  sku_name            = "B1"
}

# ======================
# Backend App Service (Linux, PHP)
# ======================
resource "azurerm_linux_web_app" "backend" {
  name                = var.app_service_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      php_version = "8.2"
    }
    app_command_line = "cp /home/site/wwwroot/default /etc/nginx/sites-available/default && service nginx reload"
  }

  app_settings = {
    APP_ENV       = "production"
    APP_DEBUG     = "false"
    APP_KEY       = "base64:VwPBpk2jFkp2o1Y32nMP8hjuugrCeADr0HdmT8ku6Ro="
    DB_CONNECTION = "sqlsrv"
    DB_HOST       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
    DB_DATABASE   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/BDNAME/)"
    DB_USERNAME   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/user/)"
    DB_PASSWORD   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/password/)"
  }
}

# ======================
# Frontend App Service (Windows, Node)
# ======================
resource "azurerm_windows_web_app" "frontend" {
  name                = var.app_service_name_web
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.plan_web.id

  site_config {
    always_on = true
    application_stack {
      node_version = "~22"
    }
  }

  app_settings = {
    WEBSITE_NODE_DEFAULT_VERSION = "~22"
  }
}

# ======================
# VNet Integration
# ======================
resource "azurerm_app_service_virtual_network_swift_connection" "backend_vnet" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.backend.id
}

# ======================
# Private Endpoints
# ======================
resource "azurerm_private_endpoint" "backend_pe" {
  name                = "pe-backend"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.privateend.id

  private_service_connection {
    name                           = "backend-connection"
    private_connection_resource_id = azurerm_linux_web_app.backend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "frontend_pe" {
  name                = "pe-frontend"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.privateend.id

  private_service_connection {
    name                           = "frontend-connection"
    private_connection_resource_id = azurerm_windows_web_app.frontend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sqlserver1"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.sql.id

  private_service_connection {
    name                           = "sqlserver1-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "keyvault_pe" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.keyvault.id

  private_service_connection {
    name                           = "keyvault-connection"
    private_connection_resource_id = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "blob_pe" {
  name                = "pe-blobstorage"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.blobstorage.id

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

# ======================
# Application Gateway
# ======================
resource "azurerm_public_ip" "appgw_ip" {
  name                = "appgw-publicip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "dojo-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "frontendPort443"
    port = 443
  }

  ssl_certificate {
    name     = "cert-app-dojo"
    data     = var.cert_data   # ahora viene del secret en GitHub
    password = var.cert_password
  }

  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "frontendPort443"
    protocol                       = "Https"
    ssl_certificate_name           = "cert-app-dojo"
  }

  backend_address_pool {
    name         = "pool-backend"
    ip_addresses = [azurerm_private_endpoint.backend_pe.private_service_connection[0].private_ip_address]
  }

  backend_address_pool {
    name         = "pool-frontend"
    ip_addresses = [azurerm_private_endpoint.frontend_pe.private_service_connection[0].private_ip_address]
  }

  backend_http_settings {
    name                  = "setting-backend"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "probe-backend"
    host_name             = "api-backend-dojo.azurewebsites.net"
    cookie_based_affinity = "Disabled"
  }

  backend_http_settings {
    name                  = "setting-frontend"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
    probe_name            = "probe-frontend"
    host_name             = "front22.azurewebsites.net"
    cookie_based_affinity = "Disabled"
  }

  probe {
    name                 = "probe-backend"
    protocol             = "Https"
    host                 = "api-backend-dojo.azurewebsites.net"
    path                 = "/api/alumnos"
    interval             = 30
    timeout              = 30
    unhealthy_threshold  = 3
    match {
      status_code = ["200-399"]
    }
  }

  probe {
    name                 = "probe-frontend"
    protocol             = "Https"
    host                 = "front22.azurewebsites.net"
    path                 = "/"
    interval             = 30
    timeout              = 30
    unhealthy_threshold  = 3
    match {
      status_code = ["200-399"]
    }
  }

  url_path_map {
    name                               = "url-path-map"
    default_backend_address_pool_name  = "pool-frontend"
    default_backend_http_settings_name = "setting-frontend"

    path_rule {
      name                       = "frontend-rule"
      paths                      = ["/web/*"]
      backend_address_pool_name  = "pool-frontend"
      backend_http_settings_name = "setting-frontend"
    }

    path_rule {
      name                       = "backend-rule"
      paths                      = ["/api/*"]
      backend_address_pool_name  = "pool-backend"
      backend_http_settings_name = "setting-backend"
    }
  }

  request_routing_rule {
    name               = "rule-path-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "listener-https"
    url_path_map_name  = "url-path-map"
    priority           = 100
  }
}

# ======================
# Role Assignment - Key Vault (Backend)
# ======================
resource "azurerm_role_assignment" "backend_kv" {
  scope                = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.key_vault_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

