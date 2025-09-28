# ======================
# Credenciales Azure
# ======================
variable "subscription_id" {
  type        = string
  description = "ID de suscripción de Azure"
}

variable "tenant_id" {
  type        = string
  description = "ID de tenant de Azure"
}

# ======================
# Grupo de recursos
# ======================
variable "resource_group_name" {
  type        = string
  description = "Nombre del grupo de recursos en Azure"
}

variable "location" {
  type        = string
  description = "Región donde se desplegarán los recursos"
}

# ======================
# Red Virtual y Subnets
# ======================
variable "vnet_name" {
  type        = string
  description = "Nombre de la red virtual"
}

variable "subnets" {
  type        = map(string)
  description = "Mapa de subnets a crear (backend, sql, keyvault, blobstorage, appgw, privateend)"
}

# ======================
# Base de datos SQL
# ======================
variable "sql_server_name" {
  type        = string
  description = "Nombre del servidor SQL"
}

variable "database_name" {
  type        = string
  description = "Nombre de la base de datos"
}

variable "sql_admin_login" {
  type        = string
  description = "Usuario administrador del SQL Server"
}

variable "sql_admin_password" {
  type        = string
  description = "Contraseña administrador del SQL Server"
  sensitive   = true
}

# ======================
# App Service Plans
# ======================
variable "app_service_plan_name" {
  type        = string
  description = "Nombre del plan de App Service (Linux)"
}

variable "app_service_plan_name_web" {
  type        = string
  description = "Nombre del plan de App Service (Windows)"
}

# ======================
# App Services
# ======================
variable "app_service_name" {
  type        = string
  description = "Nombre del App Service backend (Linux)"
}

variable "app_service_name_web" {
  type        = string
  description = "Nombre del App Service frontend (Windows)"
}

# ======================
# Integraciones
# ======================
variable "key_vault_name" {
  type        = string
  description = "Nombre del Key Vault utilizado para almacenar secretos"
}

variable "storage_account_name" {
  type        = string
  description = "Nombre de la cuenta de almacenamiento (Blob Storage)"
}

# ======================
# Certificados (para App Gateway)
# ======================
variable "cert_password" {
  type        = string
  description = "Contraseña del certificado PFX para Application Gateway"
  sensitive   = true
}

variable "cert_data" {
  type        = string
  description = "Contenido en Base64 del certificado PFX (inyectado como secret desde GitHub Actions)"
  sensitive   = true
}

