# ============================================================
# ROLES PARA KEY VAULT (BACKEND + GITHUB ACTIONS)
# ============================================================

# 1️⃣ Rol para que el App Service Backend (Identidad Administrada)
#    pueda LEER secretos desde el Key Vault
#    => Requerido para usar @Microsoft.KeyVault(SecretUri=...)
# ============================================================

resource "azurerm_role_assignment" "kv_secrets_user_backend" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id

  depends_on = [
    azurerm_linux_web_app.backend,
    azurerm_key_vault.keyvault
  ]
}

# ============================================================
# 2️⃣ Rol para que GITHUB ACTIONS (OIDC)
#    pueda CREAR y ACTUALIZAR secretos en Key Vault
#    => Requerido para usar:
#       az keyvault secret set ...
# ============================================================

resource "azurerm_role_assignment" "kv_secrets_officer_github" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.azure_client_id   # identidad federada de GitHub

  depends_on = [
    azurerm_key_vault.keyvault
  ]
}
