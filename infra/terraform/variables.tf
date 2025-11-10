variable "prefix" {
  description = "Short prefix to keep resource names unique."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "centralindia"
}

variable "node_count" {
  description = "Number of nodes for the default AKS node pool."
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for AKS worker nodes."
  type        = string
  default     = "Standard_B2s"
}

variable "vnet_address_space" {
  description = "Address space for the AKS virtual network."
  type        = list(string)
  default     = ["10.60.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "CIDR prefix for the AKS worker subnet."
  type        = string
  default     = "10.60.1.0/24"
}

variable "ssh_allowed_source_ranges" {
  description = "List of CIDR blocks permitted to access node SSH (port 22). Leave empty to disable SSH."
  type        = list(string)
  default     = []
}

variable "dns_zone_name" {
  description = "Public DNS zone to create (optional)."
  type        = string
  default     = ""

  validation {
    condition     = var.dns_zone_name == "" || can(regex("^[a-zA-Z0-9.-]+$", var.dns_zone_name))
    error_message = "dns_zone_name must be blank or a valid DNS zone name."
  }
}

variable "create_dns_zone" {
  description = "Whether to provision a public DNS zone."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
