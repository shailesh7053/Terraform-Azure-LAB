resource "azurerm_virtual_network" "demo_vnet" {
  name                = "demo-vnet"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name
  address_space       = ["10.0.0.0/16"]
}