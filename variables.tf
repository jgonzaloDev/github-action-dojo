variable "subscription_id" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "key_vault_name" {
  type = string
}

variable "github_principal_id" {
  type = string
  description = "Object ID del principal federado de GitHub"
}

# Secretos
variable "secret_bd_datos" {
  type = string
}

variable "secret_userbd" {
  type = string
}

variable "secret_passwordbd" {
  type = string
}
