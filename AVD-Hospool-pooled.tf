# main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# ============================================================
# VARIABLES
# ============================================================

variable "resource_group_name" {
  type    = string
  default = "rg-avd-hostpool"
}

variable "location" {
  type    = string
  default = "East US"
}

variable "hostpool_name" {
  type    = string
  default = "avd-hostpool-pooled"
}

variable "max_sessions_per_host" {
  type    = number
  default = 3
}

variable "avd_users_group_name" {
  description = "Entra ID security group whose members will access AVD"
  type        = string
  default     = "AVD-Users"
}

variable "session_host_count" {
  description = "Number of session host VMs"
  type        = number
  default     = 2
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "admin_username" {
  description = "Local admin username (used only for initial setup, not for user login)"
  type        = string
  default     = "avdlocaladmin"
}

variable "admin_password" {
  description = "Local admin password"
  type        = string
  sensitive   = true
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "subnet_address_prefix" {
  type    = string
  default = "10.10.1.0/24"
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
    join_type   = "EntraID"
  }
}

# ============================================================
# DATA SOURCES
# ============================================================

data "azurerm_subscription" "current" {}

data "azuread_group" "avd_users" {
  display_name     = var.avd_users_group_name
  security_enabled = true
}

# ============================================================
# RESOURCE GROUP
# ============================================================

resource "azurerm_resource_group" "avd_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ============================================================
# NETWORKING (Cloud-only, no on-prem connectivity needed)
# ============================================================

resource "azurerm_virtual_network" "avd_vnet" {
  name                = "vnet-avd"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "avd_subnet" {
  name                 = "snet-avd-hosts"
  resource_group_name  = azurerm_resource_group.avd_rg.name
  virtual_network_name = azurerm_virtual_network.avd_vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

# NSG to allow AVD traffic only
resource "azurerm_network_security_group" "avd_nsg" {
  name                = "nsg-avd-hosts"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  # Allow outbound HTTPS for AVD gateway, Entra ID, and Windows activation
  security_rule {
    name                       = "Allow-HTTPS-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Block inbound RDP from Internet (users connect via AVD gateway, not direct RDP)
  security_rule {
    name                       = "Deny-RDP-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "avd_nsg_assoc" {
  subnet_id                 = azurerm_subnet.avd_subnet.id
    network_security_group_id = azurerm_network_security_group.avd_nsg.id
}

# ============================================================
# AVD HOST POOL
# ============================================================

resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                = var.hostpool_name
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  type                             = "Pooled"
  load_balancer_type               = "BreadthFirst"
  maximum_sessions_allowed         = var.max_sessions_per_host
  friendly_name                    = "Pooled Host Pool (3 Sessions)"
  description                      = "Cloud-only AVD Pooled Host Pool - Entra ID joined"
  validate_environment             = false
  start_vm_on_connect              = true   # Saves cost — VMs start only when needed
  personal_desktop_assignment_type = "Automatic"

  # Required for Entra ID joined session hosts
  vm_template = jsonencode({
    domain                    = ""           # Empty = Entra ID join (no domain)
    galleryImageOffer         = "windows-11"
    galleryImagePublisher     = "MicrosoftWindowsDesktop"
    galleryImageSKU           = "win11-23h2-avd"
    imageType                 = "Gallery"
    customImageId             = null
    namePrefix                = "avd-host"
    osDiskType                = "Premium_LRS"
    vmSize = {
      id    = var.vm_size
      cores = 4
      ram   = 16
    }
    useManagedDisks           = true
    isManagedImage            = true
  })

  tags = var.tags
}

# ----------------------------
# Registration Token
# ----------------------------
resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), "2h")
}

# ============================================================
# AVD WORKSPACE & APPLICATION GROUP
# ============================================================

resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "avd-workspace"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  friendly_name       = "AVD Workspace"
  description         = "Cloud-only AVD Workspace"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_application_group" "dag" {
  name                = "avd-dag-pooled"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name       = "Full Desktop"
  description         = "Full desktop access for Entra ID users"
  tags                = var.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.dag.id
}

# ============================================================
# ENTRA ID RBAC ASSIGNMENTS
# ============================================================

# Grant AVD access to the Entra group on the App Group
resource "azurerm_role_assignment" "avd_user_role" {
  scope                = azurerm_virtual_desktop_application_group.dag.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_group.avd_users.object_id
}

# Grant VM login rights (required for Entra-joined VMs, no domain needed)
resource "azurerm_role_assignment" "vm_user_login" {
  scope                = azurerm_resource_group.avd_rg.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azuread_group.avd_users.object_id
}

# ============================================================
# SESSION HOST VMs
# ============================================================

resource "azurerm_network_interface" "avd_nic" {
  count               = var.session_host_count
  name                = "nic-avd-host-${count.index + 1}"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avd_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "avd_vm" {
  count               = var.session_host_count
  name                = "vm-avd-host-${count.index + 1}"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  license_type        = "Windows_Client"

  network_interface_ids = [
    azurerm_network_interface.avd_nic[count.index].id
  ]

  # System-assigned managed identity — required for Entra ID join extension
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  # Windows 11 Multi-Session — optimized for AVD Pooled
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }

  tags = var.tags
}

# ============================================================
# VM EXTENSIONS — ENTRA ID CLOUD-ONLY ORDER
# ============================================================

# ----------------------------
# EXTENSION 1: AADLoginForWindows
# Joins the VM to Entra ID (replaces domain join entirely)
# Must run FIRST before DSC
# ----------------------------
resource "azurerm_virtual_machine_extension" "aad_login" {
  count                      = var.session_host_count
  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    mdmId = ""   # Set your Intune tenant ID here to auto-enroll in Intune
  })

  tags       = var.tags
  depends_on = [azurerm_windows_virtual_machine.avd_vm]
}

# ----------------------------
# EXTENSION 2: AVD DSC Extension
# Installs AVD Agent + Boot Loader
# Registers VM into the Host Pool using the token
# aadJoin = true → No domain join, pure Entra ID
# ----------------------------
resource "azurerm_virtual_machine_extension" "avd_dsc" {
  count                      = var.session_host_count
  name                       = "AVDDSCExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      HostPoolName             = azurerm_virtual_desktop_host_pool.hostpool.name
      ResourceGroup            = azurerm_resource_group.avd_rg.name
      SubscriptionId           = data.azurerm_subscription.current.subscription_id
      Location                 = azurerm_resource_group.avd_rg.location
      UseAgentDownloadEndpoint = true
      aadJoin                  = true   # ← KEY: Entra ID join, no AD DS domain
      mdmId                    = ""     # Set Intune MDM ID if using Intune enrollment
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.registration.token
    }
  })

  tags = var.tags

  # MUST run after AADLoginForWindows
  depends_on = [azurerm_virtual_machine_extension.aad_login]
}

# ----------------------------
# EXTENSION 3: Azure Monitor Agent
# Replaces legacy MMA — sends diagnostics to Log Analytics
# Required for AVD Insights dashboard
# ----------------------------
resource "azurerm_virtual_machine_extension" "azure_monitor" {
  count                      = var.session_host_count
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = jsonencode({})

  tags       = var.tags
  depends_on = [azurerm_windows_virtual_machine.avd_vm]
}

# ============================================================
# LOG ANALYTICS + AVD DIAGNOSTICS
# ============================================================

resource "azurerm_log_analytics_workspace" "avd_law" {
  name                = "law-avd-monitoring"
  location            = azurerm_resource_group.avd_rg.location
  resource_group_name = azurerm_resource_group.avd_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Send Host Pool diagnostics to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "hostpool_diag" {
  name                       = "diag-avd-hostpool"
  target_resource_id         = azurerm_virtual_desktop_host_pool.hostpool.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_law.id

  enabled_log {
    category = "Checkpoint"
  }
  enabled_log {
    category = "Error"
  }
  enabled_log {
    category = "Management"
  }
  enabled_log {
    category = "Connection"
  }
  enabled_log {
    category = "HostRegistration"
  }
  enabled_log {
    category = "AgentHealthStatus"
  }
}

# Send Workspace diagnostics to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "workspace_diag" {
  name                       = "diag-avd-workspace"
  target_resource_id         = azurerm_virtual_desktop_workspace.workspace.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.avd_law.id

  enabled_log {
    category = "Checkpoint"
  }
  enabled_log {
    category = "Error"
  }
  enabled_log {
    category = "Management"
  }
  enabled_log {
    category = "Feed"
  }
}

# ============================================================
# OUTPUTS
# ============================================================

output "hostpool_id" {
  value = azurerm_virtual_desktop_host_pool.hostpool.id
}

output "hostpool_name" {
  value = azurerm_virtual_desktop_host_pool.hostpool.name
}

output "registration_token" {
  value     = azurerm_virtual_desktop_host_pool_registration_info.registration.token
  sensitive = true
}

output "workspace_id" {
  value = azurerm_virtual_desktop_workspace.workspace.id
}

output "session_host_names" {
  value = [for vm in azurerm_windows_virtual_machine.avd_vm : vm.name]
}

output "avd_client_url" {
  description = "URL for users to access AVD via browser"
  value       = "https://client.wvd.microsoft.com/arm/webclient/index.html"
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.avd_law.workspace_id
}
