resource "azurerm_virtual_machine_extension" "avd_agent" {
  name                 = "AVDAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_vm.id
  publisher            = "Microsoft.Azure.VirtualDesktop"
  type                 = "RDAgentBootLoader"
  type_handler_version = "1.0"

  settings = jsonencode({
    registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.registration.token
  })
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADLogin"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
}