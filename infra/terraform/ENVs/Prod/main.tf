locals {
  resource_group_name = "rg-${var.environment}"
  aks_name           = "aks-${var.environment}"
}

# Get current subscription/tenant info
data "azurerm_client_config" "current" {}

module "rg" {
  source   = "../../modules/resource_group"
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

module "acr" {
  source              = "../../modules/acr"
  name                = var.acr_name
  resource_group_name = module.rg.name
  location            = var.location
  sku                = "Basic"
  tags               = var.tags
}

# Create a VNet and subnet dedicated for AKS (required for Azure CNI)
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "vnet-${local.aks_name}"
  location            = var.location
  resource_group_name = module.rg.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-${local.aks_name}"
  location            = var.location
  resource_group_name = module.rg.name
  tags                = var.tags
}

# Allow HTTP/HTTPS from internet
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "Allow-HTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80"]
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = module.rg.name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "Allow-HTTPS"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443"]
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = module.rg.name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

# Optionally allow SSH from a bastion host / office IP
resource "azurerm_network_security_rule" "allow_ssh" {
  count                       = length(var.bastion_cidr) > 0 ? 1 : 0
  name                        = "Allow-SSH"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22"]
  source_address_prefix       = var.bastion_cidr
  destination_address_prefix  = "*"
  resource_group_name         = module.rg.name
  network_security_group_name = azurerm_network_security_group.aks_nsg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-${local.aks_name}"
  resource_group_name  = module.rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [var.subnet_prefix]
  service_endpoints    = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet_network_security_group_association" "aks_subnet_nsg" {
  subnet_id                 = azurerm_subnet.aks_subnet.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

module "aks" {
  source                         = "../../modules/aks"
  name                           = local.aks_name
  resource_group_name            = module.rg.name
  location                       = var.location
  node_count                     = var.node_count
  node_vm_size                   = var.aks_node_size
  enable_auto_scaling            = true
  min_count                      = var.node_count
  max_count                      = var.node_count * 2
  subnet_id                      = azurerm_subnet.aks_subnet.id
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  outbound_type                  = "loadBalancer"
  tags                           = var.tags
}

# Key Vault for secrets (optional)
resource "azurerm_key_vault" "aks_kv" {
  name                        = "${local.aks_name}-kv-081125"
  location                    = var.location
  resource_group_name         = module.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = []
    virtual_network_subnet_ids = [azurerm_subnet.aks_subnet.id]
  }
  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "aks_kv_policy" {
  key_vault_id = azurerm_key_vault.aks_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.aks.principal_id

  secret_permissions = ["Get", "List", "Set"]
}

# Grant AKS access to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.principal_id
}

output "acr_login_server" {
  description = "The URL that can be used to log into the container registry"
  value       = module.acr.login_server
}

output "aks_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.name
}

output "kube_config" { 
  description = "The kubeconfig for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "kube_config_command" {
  description = "Command to get the kubeconfig using Azure CLI"
  value       = module.aks.kube_config_command
}
