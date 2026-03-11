module SetPlatform
  extend ActiveSupport::Concern

  included do
    helper_method :platform
  end

  private
    def platform
      @platform ||= ApplicationPlatform.new(cookies[:x_user_agent].presence || request.user_agent)
    end
end
