resource "azurerm_role_assignment" "avd_autoscale_power" {
  scope                = azurerm_virtual_desktop_host_pool.hp.id
  role_definition_name = "Desktop Virtualization Power On Off Contributor"
  principal_id         = "9cdead84-a844-4324-93f2-b2e6bb768d07"

  # Important: This principal is Microsoft-managed, so Terraform can hang without this
  skip_service_principal_aad_check = true
}

#resource "time_sleep" "wait_for_autoscale_rbac" {
  #depends_on      = [azurerm_role_assignment.avd_autoscale_power]
  #create_duration = "900s" # 15 min (RBAC propagation)
#}

resource "azurerm_virtual_desktop_scaling_plan" "sp" {
  name                = "sp-avd-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  friendly_name = "AVD Lab Scaling Plan"
  description   = "Scaling plan for pooled host pool"
  time_zone     = "India Standard Time"

  schedule {
    name         = "Weekdays"
    days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    ramp_up_start_time                 = "09:00"
    ramp_up_load_balancing_algorithm   = "BreadthFirst"
    ramp_up_minimum_hosts_percent      = 50
    ramp_up_capacity_threshold_percent = 80

    peak_start_time               = "10:00"
    peak_load_balancing_algorithm = "BreadthFirst"

    ramp_down_start_time                 = "18:00"
    ramp_down_load_balancing_algorithm   = "BreadthFirst"
    ramp_down_minimum_hosts_percent      = 50
    ramp_down_capacity_threshold_percent = 50

    ramp_down_force_logoff_users        = false
    ramp_down_wait_time_minutes         = 30
    ramp_down_stop_hosts_when           = "ZeroSessions"
    ramp_down_notification_message      = "AVD will scale down soon. Please save your work."

    off_peak_start_time               = "20:00"
    off_peak_load_balancing_algorithm = "BreadthFirst"
  }

  host_pool {
    hostpool_id          = azurerm_virtual_desktop_host_pool.hp.id
    scaling_plan_enabled = true
  }

}
