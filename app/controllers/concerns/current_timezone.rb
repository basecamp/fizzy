# rbs_inline: enabled

# FIXME: This should move upstream to Rails. It's a good pattern.
module CurrentTimezone
  extend ActiveSupport::Concern

  included do
    around_action :set_current_timezone

    helper_method :timezone_from_cookie

    etag { timezone_from_cookie }
  end

  private
    def set_current_timezone(&)
      Time.use_zone(timezone_from_cookie, &)
    end

    def timezone_from_cookie
      @timezone_from_cookie ||= begin
        timezone = cookies[:timezone]
        ActiveSupport::TimeZone[timezone] if timezone.present?
      end
    end
end
