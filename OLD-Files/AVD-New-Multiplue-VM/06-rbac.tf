# App Group Access (Users + Admins)
resource "azurerm_role_assignment" "avd_users_appgroup" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.avd_users_group_id
}

resource "azurerm_role_assignment" "avd_admins_appgroup" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.avd_admins_group_id
}

# VM Login for Users (both session hosts)
resource "azurerm_role_assignment" "avd_users_vm_login" {
  count                = var.vm_count
  scope                = azurerm_windows_virtual_machine.vm[count.index].id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = var.avd_users_group_id
}

# VM Admin Login for Admins (both session hosts)
resource "azurerm_role_assignment" "avd_admins_vm_admin" {
  count                = var.vm_count
  scope                = azurerm_windows_virtual_machine.vm[count.index].id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = var.avd_admins_group_id
}

