resource "random_string" "suffix" {
  length  = 4
  upper   = false
  lower   = true
  special = false
}

locals {
  resource_group_name = format("%s-rg", var.prefix)
  aks_name            = format("%s-aks", var.prefix)
  acr_name            = lower(replace(format("%s%s", var.prefix, random_string.suffix.result), "-", ""))
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "aks" {
  name                = format("%s-vnet", var.prefix)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = format("%s-aks-nodes", var.prefix)
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

resource "azurerm_network_security_group" "aks" {
  name                = format("%s-aks-nsg", var.prefix)
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "allow-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "allow-lb-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-lb-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-lb-health"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10256"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = { for idx, cidr in var.ssh_allowed_source_ranges : tostring(idx) => cidr }
    content {
      name                       = format("allow-ssh-%02d", tonumber(security_rule.key))
      priority                   = 200 + tonumber(security_rule.key)
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  security_rule {
    name                       = "deny-inbound-all"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_container_registry" "acr" {
  name                = substr(local.acr_name, 0, 50)
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = format("%s-dns", var.prefix)
  depends_on          = [azurerm_subnet_network_security_group_association.aks]

  default_node_pool {
    name                 = "nodepool"
    vm_size              = var.node_vm_size
    node_count           = var.node_count
    orchestrator_version = null
    vnet_subnet_id       = azurerm_subnet.aks_nodes.id

    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  lifecycle {
    ignore_changes = [
      api_server_authorized_ip_ranges,
      default_node_pool[0].upgrade_settings
    ]
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

resource "azurerm_dns_zone" "public" {
  count               = var.create_dns_zone ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = length(trimspace(var.dns_zone_name)) > 0
      error_message = "dns_zone_name must be provided when create_dns_zone is true."
    }
  }
}
