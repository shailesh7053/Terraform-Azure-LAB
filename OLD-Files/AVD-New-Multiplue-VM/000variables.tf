variable "location" {
  type    = string
  default = "centralindia"
}

variable "resource_group_name" {
  type    = string
  default = "rg-avd-lab"
}

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "admin_username" {
  type    = string
  default = "avdadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "avd_users_group_id" {
  type = string
}

variable "avd_admins_group_id" {
  type = string
}
variable "fslogix_use_storage_key" {
  type    = bool
  default = true
}
