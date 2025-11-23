# ======================
# DATA SOURCES NECESARIOS
# ======================

data "azurerm_subscription" "primary" {}
data "azurerm_client_config" "current" {}

###############################################################
# 3️⃣ GitHub OIDC → Key Vault Secrets Officer
###############################################################
resource "azurerm_role_assignment" "github_kv_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.github_principal_id
}

###############################################################
# 4️⃣ Tu Usuario → Key Vault Administrator
###############################################################
resource "azurerm_role_assignment" "user_kv_admin" {
  scope                = azurerm_key_vault.kv.id
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
  create_duration = "45s"
}

###############################################################
# 6️⃣ Secretos (CREA O ADOPTA — NO FALLA)
###############################################################

resource "azurerm_key_vault_secret" "bd_datos" {
  name         = "BDdatos"
  value        = var.sql_database_name
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "userbd" {
  name         = "userbd"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

resource "azurerm_key_vault_secret" "passwordbd" {
  name         = "passwordbd"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.kv.id

  lifecycle {
    ignore_changes = [
      value
    ]
  }

  depends_on = [time_sleep.wait_for_iam]
}

###############################################################
# 7️⃣ Lectura final
###############################################################

data "azurerm_key_vault_secret" "bd_datos_read" {
  name         = azurerm_key_vault_secret.bd_datos.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "userbd_read" {
  name         = azurerm_key_vault_secret.userbd.name
  key_vault_id = azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "passwordbd_read" {
  name         = azurerm_key_vault_secret.passwordbd.name
  key_vault_id = azurerm_key_vault.kv.id
}