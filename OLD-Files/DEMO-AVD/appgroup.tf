resource "azurerm_virtual_desktop_application_group" "avd_dag" {
  name                = "AVD-DAG"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name

  type          = "Desktop"
  host_pool_id  = azurerm_virtual_desktop_host_pool.avd_hostpool.id

  friendly_name = "Desktop Application Group"
  description   = "Desktop App Group for AVD"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "workspace_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.avd_dag.id
}