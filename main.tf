terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# Recurso: Grupo de recursos en Azure
resource "azurerm_resource_group" "dojo" {
  name     = var.resource_group_name
  location = var.location
}
