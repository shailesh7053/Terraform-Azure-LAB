variable "resource_group_name" {
  description = "Demo-RG"
  type        = string
}

variable "resource_group_location" {
  description = "azure region"
  type        = string
  default     = "eastus"
}