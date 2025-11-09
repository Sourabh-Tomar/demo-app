output "name" {
  description = "The name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "id" {
  description = "The ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "kube_config" {
  description = "The kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kube_config_command" {
  description = "Command to get the kubeconfig using Azure CLI"
  value       = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${var.name}"
}

output "principal_id" {
  description = "The principal ID of the AKS cluster's managed identity"
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

