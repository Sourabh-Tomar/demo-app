output "acr_login_server" {
  description = "Fully qualified login server for the Azure Container Registry."
  value       = azurerm_container_registry.acr.login_server
}

output "aks_name" {
  description = "Name of the provisioned AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  description = "Base64 encoded kubeconfig for administrative access to the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "dns_zone_id" {
  description = "Resource ID of the optional DNS zone when created."
  value       = try(azurerm_dns_zone.public[0].id, null)
}
