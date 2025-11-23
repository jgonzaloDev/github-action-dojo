###############################################################
# PROVIDERS
###############################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.34.0"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

###############################################################
# 1️⃣ Key Vault EXISTENTE
###############################################################

data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

###############################################################
# 2️⃣ Otros Data Sources
###############################################################

data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

###############################################################
# 3️⃣ Rol: GitHub OIDC → Secrets Officer
###############################################################

resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id
}

###############################################################
# 4️⃣ Rol: Usuario → Administrator
###############################################################

resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = data.azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.admin_user_object_id
}

###############################################################
# 5️⃣ Espera propagación IAM
###############################################################

resource "time_sleep" "wait_for_iam" {
  depends_on = [
    azurerm_role_assignment.github_kv_secrets,
    azurerm_role_assignment.user_kv_admin
  ]
  create_duration = "90s"
}

###############################################################
# 6️⃣ Secretos
###############################################################

resource "azurerm_key_vault_secret" "bd_datos" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = data.azurerm_key_vault.kv.id

  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "userbd" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = data.azurerm_key_vault.kv.id

  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "passwordbd" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = data.azurerm_key_vault.kv.id

  lifecycle { ignore_changes = [value] }
  depends_on = [time_sleep.wait_for_iam]
}

###############################################################
# 7️⃣ Lectura Final
###############################################################

data "azurerm_key_vault_secret" "bd_datos_read" {
  name         = azurerm_key_vault_secret.bd_datos.name
  key_vault_id = data.azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_secret.bd_datos]
}

data "azurerm_key_vault_secret" "userbd_read" {
  name         = azurerm_key_vault_secret.userbd.name
  key_vault_id = data.azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_secret.userbd]
}

data "azurerm_key_vault_secret" "passwordbd_read" {
  name         = azurerm_key_vault_secret.passwordbd.name
  key_vault_id = data.azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_secret.passwordbd]
}
