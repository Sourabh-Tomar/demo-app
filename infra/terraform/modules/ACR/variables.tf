variable "name" {
  description = "Name of the Azure Container Registry. Must be globally unique."
  type        = string
}

variable "location" {
  description = "Azure region where the ACR will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where ACR will be created"
  type        = string
}

variable "sku" {
  description = "SKU for the Azure Container Registry"
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags to be applied to the ACR"
  type        = map(string)
  default     = {}
}
