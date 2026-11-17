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