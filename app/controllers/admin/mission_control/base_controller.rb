module Admin
  module MissionControl
    class BaseController < ::AdminController
      # Use Mission Control's default layout to preserve its tabs (Queues, Failed jobs)
      # Mission Control will handle its own UI
    end
  end
end


