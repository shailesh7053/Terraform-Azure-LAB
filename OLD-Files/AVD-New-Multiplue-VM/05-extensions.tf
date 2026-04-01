resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.vm_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "avd_dsc" {
  count                      = var.vm_count
  name                       = "AVD-DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.83"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_01-19-2023.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName          = azurerm_virtual_desktop_host_pool.hp.name
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.reg.token
    }
  })

  depends_on = [
    azurerm_virtual_machine_extension.aad_login
  ]
}
