resource "azurerm_public_ip" "avd_pip" {
  name                = "avd-pip"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name

  allocation_method   = "Static"
  sku                 = "Standard"
}