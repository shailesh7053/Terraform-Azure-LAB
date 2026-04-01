resource "azurerm_virtual_desktop_host_pool" "avd_hostpool" {
  name                = "AVD-hostpool"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name

  type                     = "Pooled"   # Pooled or Personal
  load_balancer_type       = "DepthFirst"
  maximum_sessions_allowed = 10
  preferred_app_group_type = "Desktop"

  start_vm_on_connect      = true
  validate_environment     = true

  description = "Demo AVD Host Pool"
}