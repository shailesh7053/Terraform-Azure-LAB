resource "azurerm_virtual_desktop_host_pool_registration_info" "reg" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hp.id
  expiration_date = timeadd(timestamp(), "24h")
}