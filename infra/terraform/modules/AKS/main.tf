resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.name}-dns"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # Restrict API server access when provided
  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size            = var.node_vm_size
    os_disk_size_gb    = 30
    type               = "VirtualMachineScaleSets"
    node_labels = {
      "environment" = "production"
    }

    # If a subnet is provided (Azure CNI), place nodes into it
    vnet_subnet_id = var.subnet_id != "" ? var.subnet_id : null

    # Required for updating node pool properties
    temporary_name_for_rotation = "tempnp"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "azure"
    outbound_type     = var.outbound_type
  }
}
