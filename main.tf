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

# ============================================================
# 1.0 - Grupo de Recursos y Red Virtual
# ============================================================

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# -----------------------------
# 1.1 Subnet - Application Gateway
# -----------------------------
resource "azurerm_subnet" "subnet_agw" {
  name                 = "subnet-agw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# -----------------------------
# 1.2 Subnet - App Services (Backend + Frontend)
# -----------------------------
resource "azurerm_subnet" "subnet_appservices" {
  name                 = "subnet-appservices"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# -----------------------------
# 1.3 Subnet - Integración (Backend)
# -----------------------------
resource "azurerm_subnet" "subnet_integration" {
  name                 = "subnet-integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# -----------------------------
# 1.4 Subnet - Private Endpoints (Key Vault, SQL, Blob)
# -----------------------------
resource "azurerm_subnet" "subnet_pe" {
  name                 = "subnet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# ============================================================
# 2.0 - App Services
# ============================================================

# -----------------------------
# 2.1 Plan Linux (Backend)
# -----------------------------
resource "azurerm_service_plan" "plan_backend" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# -----------------------------
# 2.2 Plan Windows (Frontend)
# -----------------------------
resource "azurerm_service_plan" "plan_frontend" {
  name                = var.app_service_plan_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "B1"
}

# -----------------------------
# 2.3 Backend App Service (PHP)
# -----------------------------
resource "azurerm_linux_web_app" "backend" {
  name                = var.app_service_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_backend.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true
    application_stack {
      php_version = "8.2"
    }
  }

  app_settings = {
    APP_ENV       = "production"
    APP_DEBUG     = "false"
    APP_KEY       = "base64:VwPBpk2jFkp2o1Y32nMP8hjuugrCeADr0HdmT8ku6Ro="
    DB_CONNECTION = "sqlsrv"
    DB_HOST       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
    DB_DATABASE   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/DB_DATABASE/)"
    DB_USERNAME   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/DB_USERNAME/)"
    DB_PASSWORD   = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/DB_PASSWORD/)"
  }
}

# -----------------------------
# 2.4 Frontend App Service (Node)
# -----------------------------
resource "azurerm_windows_web_app" "frontend" {
  name                = var.app_service_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan_frontend.id

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

# -----------------------------
# 2.5 Integración del backend con subnet-integration
# -----------------------------
resource "azurerm_app_service_virtual_network_swift_connection" "backend_vnet" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# ============================================================
# 3.0 - Application Gateway
# ============================================================

resource "azurerm_public_ip" "appgw_ip" {
  name                = "appgw-publicip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "dojo-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip"
    subnet_id = azurerm_subnet.subnet_agw.id
  }

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "port443"
    port = 443
  }

  ssl_certificate {
    name     = "cert-app-dojo"
    data     = var.cert_data
    password = var.cert_password
  }

  http_listener {
    name                           = "listener-https"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name             = "port443"
    protocol                       = "Https"
    ssl_certificate_name           = "cert-app-dojo"
  }

  backend_address_pool {
    name         = "pool-backend"
    ip_addresses = [azurerm_linux_web_app.backend.outbound_ip_addresses[0]]
  }

  backend_address_pool {
    name         = "pool-frontend"
    ip_addresses = [azurerm_windows_web_app.frontend.outbound_ip_addresses[0]]
  }

  backend_http_settings {
    name            = "setting-backend"
    port            = 443
    protocol        = "Https"
    request_timeout = 30
    probe_name      = "probe-backend"
  }

  backend_http_settings {
    name            = "setting-frontend"
    port            = 443
    protocol        = "Https"
    request_timeout = 30
    probe_name      = "probe-frontend"
  }

  probe {
    name                = "probe-backend"
    protocol            = "Https"
    host                = "api-backend-dojo.azurewebsites.net"
    path                = "/api/alumnos"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match { status_code = ["200-399"] }
  }

  probe {
    name                = "probe-frontend"
    protocol            = "Https"
    host                = "front22.azurewebsites.net"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match { status_code = ["200-399"] }
  }

  url_path_map {
    name                               = "url-map"
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
    name               = "rule-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "listener-https"
    url_path_map_name  = "url-map"
    priority           = 100
  }
}

# ============================================================
# 4.0 - Key Vault, SQL Server, Blob Storage
# ============================================================

# 4.1 Key Vault
resource "azurerm_key_vault" "keyvault" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
}

# 4.2 Secretos del Key Vault
resource "azurerm_key_vault_secret" "db_name" {
  name         = "DB_DATABASE"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "DB_USERNAME"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "db_pass" {
  name         = "DB_PASSWORD"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
}

# 4.3 SQL Server y Base de Datos
resource "azurerm_mssql_server" "sql_server" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.rg.name
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

# 4.4 Blob Storage
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# 4.5 Asignación de permisos Key Vault para el backend
resource "azurerm_role_assignment" "backend_kv" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}
