# -----------------------------
# AVD Groups Object IDs
# -----------------------------
locals {
  avd_users_group_id  = "e05bb990-a2a9-4c52-a4e5-32813f8b4a1b"
  avd_admins_group_id = "ab32676c-0101-40a6-aa40-6e7159d75a5a"
}

# -----------------------------
# App Group Access (Both groups)
# -----------------------------
resource "azurerm_role_assignment" "avd_users_appgroup" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = local.avd_users_group_id
}

resource "azurerm_role_assignment" "avd_admins_appgroup" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = local.avd_admins_group_id
}

# -----------------------------
# VM Login Roles
# -----------------------------
resource "azurerm_role_assignment" "avd_users_vm_login" {
  scope                = azurerm_windows_virtual_machine.vm.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = local.avd_users_group_id
}

resource "azurerm_role_assignment" "avd_admins_vm_admin" {
  scope                = azurerm_windows_virtual_machine.vm.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = local.avd_admins_group_id
}



