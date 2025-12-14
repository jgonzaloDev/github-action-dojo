terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.34.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "time" {}

# ============================================================
# 0.1 - GRUPO DE RECURSOS
# ============================================================

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# ============================================================
# 0.2 - RED VIRTUAL
# ============================================================

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# -----------------------------
# 0.2.1 - SUBNETS
# -----------------------------

resource "azurerm_subnet" "subnet_agw" {
  name                 = "subnet-agw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

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

resource "azurerm_subnet" "subnet_integration" {
  name                 = "subnet-integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "subnet_pe" {
  name                 = "subnet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# ============================================================
# APP SERVICE PLAN (BACKEND)
# ============================================================

resource "azurerm_service_plan" "plan_backend" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# ============================================================
# 1.0 - Backend App Service (Linux, PHP)
# ============================================================

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

    app_command_line = "cp /home/site/wwwroot/default /etc/nginx/sites-available/default && service nginx reload"
  }

  app_settings = {
    APP_ENV   = "production"
    APP_DEBUG = "false"

    DB_CONNECTION = "sqlsrv"
    DB_HOST       = azurerm_mssql_server.sql_server.fully_qualified_domain_name

    DB_DATABASE = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-database/)"
    DB_USERNAME = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-username/)"
    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=https://${var.key_vault_name}.vault.azure.net/secrets/db-password/)"
  }
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "subnet_integration" {
  app_service_id = azurerm_linux_web_app.backend.id
  subnet_id      = azurerm_subnet.subnet_integration.id
}

# ============================================================
# 1.1 - KEY VAULT (CORREGIDO)
# ============================================================

resource "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = var.tenant_id

  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
}

# ------------------------------------------------------------
# ROLES
# ------------------------------------------------------------

resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id
}

resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_user_object_id
}

# Espera propagación
resource "time_sleep" "wait_for_iam" {
  create_duration = "45s"
  depends_on = [
    azurerm_role_assignment.github_kv_secrets,
    azurerm_role_assignment.user_kv_admin
  ]
}

# ------------------------------------------------------------
# Secretos Alineados
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id
  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

# ============================================================
# 1.2 - SQL SERVER Y BASE DE DATOS
# ============================================================

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

# ============================================================
# 1.3 - STORAGE ACCOUNT
# ============================================================

resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ============================================================
# APP SERVICE PLAN (FRONTEND)
# ============================================================

resource "azurerm_service_plan" "plan_frontend" {
  name                = var.app_service_plan_name_web
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "B1"
}

# ============================================================
# WINDOWS WEB APP (FRONTEND)
# ============================================================

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

# =================================================================================
# Public IP para Application Gateway
# ================================================================================
resource "azurerm_public_ip" "appgw_ip" {
  name                = "appgw-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =================================================================================
# Private Endpoints
# ================================================================================

# ✅ CORREGIDO: Ahora usa subnet_pe en lugar de privateend
resource "azurerm_private_endpoint" "backend_pe" {
  name                = "pe-backend"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "backend-connection"
    private_connection_resource_id = azurerm_linux_web_app.backend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_linux_web_app.backend
  ]
}

# ✅ CORREGIDO: Ahora usa subnet_pe en lugar de privateend
resource "azurerm_private_endpoint" "frontend_pe" {
  name                = "pe-frontend"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "frontend-connection"
    private_connection_resource_id = azurerm_windows_web_app.frontend.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_windows_web_app.frontend
  ]
}

# ✅ CORREGIDO: Ahora usa subnet_pe en lugar de sql
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "pe-sqlserver1"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "sqlserver1-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_mssql_server.sql_server
  ]
}

# ✅ CORREGIDO: Ahora usa subnet_pe y referencia directa al Key Vault
resource "azurerm_private_endpoint" "keyvault_pe" {
  name                = "pe-keyvault"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_key_vault.kv
  ]
}

# ✅ CORREGIDO: Ahora usa subnet_pe y referencia directa al Storage Account
resource "azurerm_private_endpoint" "blob_pe" {
  name                = "pe-blobstorage"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "blob-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_subnet.subnet_pe,
    azurerm_storage_account.storage
  ]
}

# =================================================================================
# Application Gateway
# ================================================================================

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
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.subnet_agw.id
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
    data     = var.cert_data
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

  depends_on = [
    azurerm_public_ip.appgw_ip,
    azurerm_private_endpoint.backend_pe,
    azurerm_private_endpoint.frontend_pe
  ]
}
