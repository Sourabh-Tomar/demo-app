variable "name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region where the AKS cluster will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where AKS will be created"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for the nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to use"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to be applied to the AKS cluster"
  type        = map(string)
  default     = {}
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for the default node pool"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "Minimum number of nodes when auto scaling is enabled"
  type        = number
  default     = 2
}

variable "max_count" {
  description = "Maximum number of nodes when auto scaling is enabled"
  type        = number
  default     = 5
}

variable "subnet_id" {
  description = "Subnet resource id where AKS node pool will be deployed (azure CNI)"
  type        = string
  default     = ""
}

variable "api_server_authorized_ip_ranges" {
  description = "List of CIDR blocks allowed to access the Kubernetes API server"
  type        = list(string)
  default     = []
}

variable "outbound_type" {
  description = "AKS outbound type - loadBalancer | userDefinedRouting"
  type        = string
  default     = "loadBalancer"
}
