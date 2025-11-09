terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "01f45d0e-b678-42f9-b3fe-1801f07624db"
  resource_provider_registrations = "none"
}