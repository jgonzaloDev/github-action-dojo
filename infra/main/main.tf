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
# 1.0 - APP SERVICE BACKEND
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

    # (Tu comando personalizado)
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
  value        = var.sql_database_name
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

# Lectura final (opcional)
data "azurerm_key_vault_secret" "db_database_read" {
  name         = azurerm_key_vault_secret.db_database.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "db_username_read" {
  name         = azurerm_key_vault_secret.db_username.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "db_password_read" {
  name         = azurerm_key_vault_secret.db_password.name
  key_vault_id = azurerm_key_vault.kv.id
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
# 1.4 - PRIVATE ENDPOINTS
# ============================================================

resource "azurerm_private_endpoint" "pe_sql" {
  name                = "pe-sql"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "sql-connection"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

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
}

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
