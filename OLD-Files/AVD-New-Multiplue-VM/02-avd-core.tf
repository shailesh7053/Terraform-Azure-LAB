resource "azurerm_virtual_desktop_host_pool" "hp" {
  name                = "hp-avd-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 6

  preferred_app_group_type = "Desktop"

  # IMPORTANT for Entra ID join
  validate_environment = false

  # IMPORTANT for Entra auth
  custom_rdp_properties = "targetisaadjoined:i:1;enablerdsaadauth:i:1"
}

resource "azurerm_virtual_desktop_workspace" "ws" {
  name                = "ws-avd-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  friendly_name = "AVD Lab Workspace"
  description   = "Workspace for AVD lab"
}

resource "azurerm_virtual_desktop_application_group" "dag" {
  name                = "dag-avd-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type         = "Desktop"
  host_pool_id = azurerm_virtual_desktop_host_pool.hp.id

  friendly_name = "AVD Lab Desktop"
  description   = "Desktop App Group for pooled host pool"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "ws_dag_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.ws.id
  application_group_id = azurerm_virtual_desktop_application_group.dag.id
}
