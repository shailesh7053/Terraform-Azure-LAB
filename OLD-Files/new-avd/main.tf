# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-avd-entra-demo"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-avd-entra"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-avd"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# NIC
resource "azurerm_network_interface" "nic" {
  name                = "nic-avd-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Host Pool
resource "azurerm_virtual_desktop_host_pool" "hp" {
  name                = "hp-avd-entra"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 10
  preferred_app_group_type = "Desktop"
}

# Registration Token
resource "azurerm_virtual_desktop_host_pool_registration_info" "reg" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hp.id
  expiration_date = timeadd(timestamp(), "24h")
}

# Windows 11 Multi-session VM (Entra ID Join)
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "avd-entra-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_D4s_v5"

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }
}

# Entra ID Join Extension
resource "azurerm_virtual_machine_extension" "entra_join" {
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "1.0"
}

# AVD Agent Extension
resource "azurerm_virtual_machine_extension" "avd_agent" {
  name                 = "AVDAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.VirtualDesktop"
  type                 = "VirtualDesktopAgent"
  type_handler_version = "1.0"

  settings = jsonencode({
    hostPoolName = azurerm_virtual_desktop_host_pool.hp.name
  })

  protected_settings = jsonencode({
    registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.reg.token
  })
}