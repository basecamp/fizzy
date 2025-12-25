# rbs_inline: enabled

module RoutingHeaders
  extend ActiveSupport::Concern

  included do
    before_action :set_target_header
  end

  private
    def set_target_header
      response.headers["X-Kamal-Target"] = request.headers["X-Kamal-Target"]
    end
end
