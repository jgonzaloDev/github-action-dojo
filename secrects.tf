# ============================================================
# KEYVAULT SECRETS – CREATION FROM TERRAFORM
# ============================================================

# DATABASE NAME
resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.keyvault.id
}

# DATABASE USERNAME
resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.keyvault.id
}

# DATABASE PASSWORD
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
}
# DATABASE HOST
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  key_vault_id = azurerm_key_vault.keyvault.id

  depends_on = [
    azurerm_mssql_server.sql_server
  ]
}
