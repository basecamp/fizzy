Rails.application.config.before_initialize do
  MissionControl::Jobs.base_controller_class = "AdminController"
  MissionControl::Jobs.show_console_help = false
end
