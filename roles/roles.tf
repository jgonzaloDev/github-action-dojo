# ============================================================
# ROLE ASSIGNMENTS – BACKEND APP SERVICE
# ============================================================

resource "azurerm_role_assignment" "kv_secrets_officer_backend" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id

  depends_on = [
    azurerm_key_vault.keyvault,
    azurerm_linux_web_app.backend
  ]
}
