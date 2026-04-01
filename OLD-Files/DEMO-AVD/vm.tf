resource "azurerm_windows_virtual_machine" "avd_vm" {
  name                = "avd-pool-vm01"
  computer_name       = "avd-pool"
  resource_group_name = azurerm_resource_group.demo_rg.name
  location            = azurerm_resource_group.demo_rg.location
  size                = "Standard_D4s_v5"

  admin_username = "azureuser"
  admin_password = "P@ssword1234!"   # use Key Vault in real production

  network_interface_ids = [
    azurerm_network_interface.avd_nic.id
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
  publisher = "MicrosoftWindowsDesktop"
  offer     = "windows-11"
  sku       = "win11-22h2-avd"
  version   = "latest"
}
}