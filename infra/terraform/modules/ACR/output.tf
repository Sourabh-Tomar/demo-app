output "login_server" {
  description = "The URL that can be used to log into the container registry"
  value       = azurerm_container_registry.this.login_server
}

output "id" {
  description = "The ID of the Container Registry"
  value       = azurerm_container_registry.this.id
}

output "admin_username" {
  description = "The admin username for the Container Registry"
  value       = azurerm_container_registry.this.admin_username
  sensitive   = true
}

output "admin_password" {
  description = "The admin password for the Container Registry"
  value       = azurerm_container_registry.this.admin_password
  sensitive   = true
}
