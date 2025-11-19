# ============================================================
# VARIABLES PRINCIPALES
# ============================================================

variable "subscription_id" {
  description = "ID de la suscripción de Azure"
  type        = string
}

variable "tenant_id" {
  description = "ID del tenant de Azure"
  type        = string
}

variable "location" {
  description = "Ubicación de los recursos (por ejemplo: eastus2)"
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
}

# ============================================================
# VIRTUAL NETWORK Y SUBNETS
# ============================================================

variable "vnet_name" {
  description = "Nombre de la red virtual principal"
  type        = string
}

# ============================================================
# APP SERVICE PLANS Y WEB APPS
# ============================================================

variable "app_service_plan_name" {
  description = "Nombre del App Service Plan para backend (Linux)"
  type        = string
}

variable "app_service_plan_name_web" {
  description = "Nombre del App Service Plan para frontend (Windows)"
  type        = string
}

variable "app_service_name" {
  description = "Nombre del App Service backend"
  type        = string
}

variable "app_service_name_web" {
  description = "Nombre del App Service frontend"
  type        = string
}

# ============================================================
# CERTIFICADO PARA APPLICATION GATEWAY
# ============================================================

variable "cert_data" {
  description = "Certificado SSL codificado en base64"
  type        = string
}

variable "cert_password" {
  description = "Contraseña del certificado SSL"
  type        = string
}

# ============================================================
# BASE DE DATOS SQL SERVER
# ============================================================

variable "sql_server_name" {
  description = "Nombre del servidor SQL"
  type        = string
}

variable "sql_admin_login" {
  description = "Usuario administrador del SQL Server"
  type        = string
}

variable "sql_admin_password" {
  description = "Contraseña del usuario administrador del SQL Server"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Nombre de la base de datos"
  type        = string
}

# ============================================================
# KEY VAULT Y STORAGE
# ============================================================

variable "key_vault_name" {
  description = "Nombre del Key Vault principal"
  type        = string
}

variable "storage_account_name" {
  description = "Nombre de la cuenta de almacenamiento (Blob)"
  type        = string
}

# ============================================================
# OPCIONAL: SUBNETS COMO MAPA (si deseas manejarlo dinámico)
# ============================================================

variable "subnets" {
  description = "Mapa de subnets (para compatibilidad o migración futura)"
  type        = map(string)
  default = {
    agw          = "subnet-agw"
    appservices  = "subnet-appservices"
    integration  = "subnet-integration"
    privateend   = "subnet-pe"
  }
}

# ============================================================
# ID de la identidad federada (OIDC) de GitHub Actions
# ============================================================

variable "azure_client_id" {
  description = "Client ID de la identidad federada de GitHub (OIDC)"
  type        = string
}
