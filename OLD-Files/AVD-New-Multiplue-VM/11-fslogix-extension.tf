resource "azurerm_virtual_machine_extension" "fslogix" {
  count                      = var.vm_count
  name                       = "FSLogix"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = <<-PS
      powershell -ExecutionPolicy Bypass -Command "
      Set-ExecutionPolicy Bypass -Scope Process -Force;

      # -------------------------
      # Kerberos client tuning (Entra Kerberos Azure Files)
      # -------------------------
      New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters' -Force | Out-Null
      New-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters' -Name 'SupportedEncryptionTypes' -PropertyType DWord -Value 0x7FFFFFFF -Force | Out-Null

      # -------------------------
      # Download + Install FSLogix
      # -------------------------
      $zip = 'C:\\Temp\\fslogix.zip'
      New-Item -ItemType Directory -Path C:\\Temp -Force | Out-Null
      Invoke-WebRequest -Uri 'https://aka.ms/fslogix_download' -OutFile $zip
      Expand-Archive $zip -DestinationPath C:\\Temp\\fslogix -Force

      $installer = Get-ChildItem -Path C:\\Temp\\fslogix -Recurse -Filter 'FSLogixAppsSetup.exe' | Select-Object -First 1
      Start-Process -FilePath $installer.FullName -ArgumentList '/install','/quiet','/norestart' -Wait

      # -------------------------
      # FSLogix registry settings
      # -------------------------
      New-Item -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Force | Out-Null
      Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name Enabled -Type DWord -Value 1
      Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name DeleteLocalProfileWhenVHDShouldApply -Type DWord -Value 1

      $sharePath = '\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.fslogix.name}'
      New-ItemProperty -Path 'HKLM:\\SOFTWARE\\FSLogix\\Profiles' -Name VHDLocations -PropertyType MultiString -Value $sharePath -Force | Out-Null

      Restart-Service frxsvc -Force
      "
    PS
  })

  depends_on = [
    azurerm_storage_share.fslogix
  ]
}
