data "azurerm_client_config" "current" {}

# -------------------------------------------------------------
# Rol para que el Backend (MSI) lea secretos del Key Vault
# -------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_user_backend" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

# -------------------------------------------------------------
# Rol para que GitHub cree secretos (opcional)
# -------------------------------------------------------------
resource "azurerm_role_assignment" "kv_secrets_officer_github" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.azure_client_id
}
