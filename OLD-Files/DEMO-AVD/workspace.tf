resource "azurerm_virtual_desktop_workspace" "avd_workspace" {
  name                = "AVD-Workspace"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name

  friendly_name = "Demo AVD Workspace"
  description   = "Workspace for AVD Demo"
}