# Give AVD users access to the Azure Files share using Entra ID
resource "azurerm_role_assignment" "fslogix_users_share" {
  scope                = azurerm_storage_account.fslogix.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.avd_users_group_id
}

# Optional: Admins can manage permissions
resource "azurerm_role_assignment" "fslogix_admins_share" {
  scope                = azurerm_storage_account.fslogix.id
  role_definition_name = "Storage File Data SMB Share Elevated Contributor"
  principal_id         = var.avd_admins_group_id
}
