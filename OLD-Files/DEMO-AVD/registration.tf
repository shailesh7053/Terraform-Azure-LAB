resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_hostpool.id
  expiration_date = timeadd(timestamp(), "24h")
}