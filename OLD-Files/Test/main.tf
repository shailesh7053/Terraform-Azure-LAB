# 1. Resource Group
resource "azurerm_resource_group" "avd_rg" {
  name     = "rg-avd-multisession"
  location = "centralindia"
}

# 2. Networking
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-avd"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-avd"
  resource_group_name  = azurerm_resource_group.avd_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_network_interface" "nic" {
  name                = "avd-vm-nic"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  # Forces Terraform to wait for the subnet to be fully ready
  depends_on = [
    azurerm_subnet.subnet
  ]
}
# 3. AVD Host Pool
resource "azurerm_virtual_desktop_host_pool" "pool" {
  name                     = "hp-windows11-multi"
  location                 = azurerm_resource_group.avd_rg.location
  resource_group_name      = azurerm_resource_group.avd_rg.name
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  maximum_sessions_allowed = 6
  friendly_name            = "Win11 Multi-session Pool"
  
  # Required for Entra ID Join login
  custom_rdp_properties    = "targetisaadjoined:i:1;aadmxinfo:i:1;"
}

# Registration Info (Token for VM to join pool)

# 1. Generates a stable time token that rotates every 1 day
resource "time_rotating" "avd_token" {
  rotation_days = 1
}

# 2. Applies the token to the Host Pool
resource "azurerm_virtual_desktop_host_pool_registration_info" "token" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.pool.id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

# 4. Application Group & Workspace
resource "azurerm_virtual_desktop_application_group" "dag" {
  name                = "dag-desktop"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.pool.id
}

resource "azurerm_virtual_desktop_workspace" "ws" {
  name                = "ws-avd"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "workassoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.ws.id
  application_group_id = azurerm_virtual_desktop_application_group.dag.id
}

# 5. Virtual Machine (Session Host)
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "avd-sh-01"
  resource_group_name   = azurerm_resource_group.avd_rg.name
  location              = azurerm_resource_group.avd_rg.location
  size                  = "Standard_D4s_v3" # Using the size from your screenshot
  admin_username        = "adminuser"
  admin_password        = "P@ssword1234!" 
  network_interface_ids = [azurerm_network_interface.nic.id]

  # Required for clean Entra ID Join
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }
}

# 6. Extensions (Entra Join & AVD Agent)

# Runs First: Joins the VM to Entra ID
resource "azurerm_virtual_machine_extension" "entra_join" {
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Runs Second: Registers to AVD (Notice the aadJoin parameter and depends_on)
resource "azurerm_virtual_machine_extension" "avd_agent" {
  name                       = "dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  # CRITICAL: Forces Terraform to wait for Entra Join to finish
  depends_on = [azurerm_virtual_machine_extension.entra_join]

  settings = <<SETTINGS
    {
        "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip",
        "configurationFunction": "Configuration.ps1\\AddSessionHost",
        "properties": {
            "hostPoolName": "${azurerm_virtual_desktop_host_pool.pool.name}",
            "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.token.token}",
            "aadJoin": true
        }
    }
SETTINGS
}

# Variables for your Group IDs
variable "avd_users_group_id" {
  default = "e05bb990-a2a9-4c52-a4e5-32813f8b4a1b"
}

variable "avd_admins_group_id" {
  default = "ab32676c-0101-40a6-aa40-6e7159d75a5a"
}

# --- USER ACCESS ---

# 1. AVD Role: Allows users to see the Desktop icon in the AVD Client
resource "azurerm_role_assignment" "avd_user_desktop_app_group" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.avd_users_group_id
}

# 2. VM Login Role: Allows users to authenticate into the Windows 11 VM via Entra ID
resource "azurerm_role_assignment" "vm_user_login" {
  scope                = azurerm_resource_group.avd_rg.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = var.avd_users_group_id
}

# --- ADMIN ACCESS ---

# 3. VM Admin Role: Allows admins to log in with local administrator privileges
resource "azurerm_role_assignment" "vm_admin_login" {
  scope                = azurerm_resource_group.avd_rg.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = var.avd_admins_group_id
}