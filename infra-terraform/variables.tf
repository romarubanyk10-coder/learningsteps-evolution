variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "project" {
  description = "Short project name used in resource names"
  type        = string
  default     = "learningsteps"
}

variable "tags" {
  description = "Tags added to every resource"
  type        = map(string)
  default = {
    project    = "learningsteps-evolution"
    managed_by = "terraform"
  }
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for AKS"
  type        = string
  default     = "1.36"
}

variable "aks_node_vm_size" {
  description = "VM size of the AKS node"
  type        = string
  default     = "Standard_D2s_v6"
}
variable "kv_allowed_ips" {
  description = "Public IPs allowed to reach Key Vault (your own IP for Terraform). Set in terraform.tfvars, not in git."
  type        = list(string)
  default     = []
}
variable "postgres_sku" {
  description = "PostgreSQL Flexible Server size (tier_family_size)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_zone" {
  description = "Availability zone for PostgreSQL; pinned because the automatic choice failed with SkuNotAvailable"
  type        = string
  default     = "1"
}
