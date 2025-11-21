# ============================================================
# 1. Data Sources necesarios
# ============================================================
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# ============================================================
# 2. Key Vault (RBAC activado + admin OIDC)
# ============================================================

resource "azurerm_key_vault" "keyvault" {
  name                        = var.key_vault_name
  location                    = data.azurerm_resource_group.rg.location
  resource_group_name         = data.azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true

  sku_name = "standard"
}

# ============================================================
# 3. Rol: Key Vault Administrator para GitHub (OIDC)
# ============================================================

resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================
# 4. Llave RSA para CI/CD (opcional pero recomendado)
# ============================================================

resource "azurerm_key_vault_key" "ci_cd_key" {
  name         = "ci-cd-rsa-key"
  key_vault_id = azurerm_key_vault.keyvault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = ["decrypt", "encrypt", "sign", "unwrapKey", "verify"]

  rotation_policy {
    automatic {
      time_before_expiry = "P300D"
    }

    expire_after         = "P900D"
    notify_before_expiry = "P31D"
  }
}

# ============================================================
# 5. Secretos SQL (username, password, database)
# ============================================================

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.sql_admin_login
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "db_database" {
  name         = "db-database"
  value        = var.database_name
  key_vault_id = azurerm_key_vault.keyvault.id
}

# ============================================================
# 6. Rol para el Backend (Managed Identity)
# ============================================================

resource "azurerm_role_assignment" "backend_kv_secrets" {
  scope                = azurerm_key_vault.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.backend.identity[0].principal_id
}

# ============================================================
# 7. Private Endpoint del Key Vault
# ============================================================

resource "azurerm_private_endpoint" "pe_keyvault" {
  name                = "pe-keyvault"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.keyvault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

# ============================================================
# 8. Private DNS Zone para Key Vault
# ============================================================

resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_a_record" "kv_a_record" {
  name                = lower(azurerm_key_vault.keyvault.name)
  zone_name           = azurerm_private_dns_zone.kv_dns.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 300
  records             = [
    azurerm_private_endpoint.pe_keyvault.private_service_connection[0].private_ip_address
  ]
}
