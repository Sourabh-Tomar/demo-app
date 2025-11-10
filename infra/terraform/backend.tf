terraform {
	backend "azurerm" {
		resource_group_name  = "dstdemo-tfstate-rg"
		storage_account_name = "dstdemotfstate9534"
		container_name       = "tfstate"
		key                  = "infra.tfstate"
		use_azuread_auth     = true
	}
}

