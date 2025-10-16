ActiveSupport.on_load(:action_controller_base) do
  before_action { logger.struct tenant: ApplicationRecord.current_tenant }
end
