Rails.application.config.before_initialize do
  MissionControl::Jobs.base_controller_class = "AdminController"
end
