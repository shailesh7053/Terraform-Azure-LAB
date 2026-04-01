resource "azurerm_subnet_network_security_group_association" "demo_assoc" {
  subnet_id                 = azurerm_subnet.demo_subnet.id
  network_security_group_id = azurerm_network_security_group.demo_nsg.id
}