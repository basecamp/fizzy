#
#  Cloudflare sets a True-Client-IP header, which for most 37signals apps gets copied to
#  X-Forwarded-For by an iRule on the F5 load balancers:
#
#  https://github.com/basecamp/f5-tf/blob/1543f7bfa3961a79e397f80cf041d75567f1b2f8/ams-base/iRules/manage_x_forwarded.tcl
#
#  However, for Fizzy the F5s are configured to do passthrough, so the header value isn't being
#  copied for us. Let's do that bit of work here, before Rails' RemoteIp middleware.
#
class TrackTrueClientIp
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["HTTP_TRUE_CLIENT_IP"].present?
      env["HTTP_X_FORWARDED_FOR"] = env["HTTP_TRUE_CLIENT_IP"]
    end

    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::RemoteIp, TrackTrueClientIp
