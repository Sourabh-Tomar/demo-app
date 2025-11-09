variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Environment name for tagging and naming resources"
  type        = string
  default     = "prod"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "acrdev081125st"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "Size of AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    app         = "demo-app"
  }
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_prefix" {
  description = "Subnet prefix for AKS nodes"
  type        = string
  default     = "10.1.1.0/24"
}

variable "bastion_cidr" {
  description = "CIDR allowed to access SSH (port 22) - leave empty to disable SSH access"
  type        = string
  default     = ""
}

variable "api_server_authorized_ip_ranges" {
  description = "List of CIDR ranges allowed to access the Kubernetes API server"
  type        = list(string)
  default     = []
}
