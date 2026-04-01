resource "azurerm_storage_account" "fslogix" {
  name                = "stfslogix${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_share" "fslogix" {
  name                 = "fslogix"
  storage_account_name = azurerm_storage_account.fslogix.name
  quota                = 100
}
