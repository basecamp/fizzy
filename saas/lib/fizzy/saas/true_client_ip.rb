#
#  Cloudflare sets a True-Client-IP header, which for most 37signals apps gets copied to
#  X-Forwarded-For by an iRule on the F5 load balancers:
#
#  https://github.com/basecamp/f5-tf/blob/1543f7bfa3961a79e397f80cf041d75567f1b2f8/ams-base/iRules/manage_x_forwarded.tcl
#
#  However, for Fizzy the F5s are configured to do passthrough, so the header value isn't being
#  copied for us. Let's do that bit of work here, before Rails' RemoteIp middleware.
#
#  Since kamal-proxy 0.10.0 the load balancer does the same copy for us
#  (--client-ip-header=True-Client-IP in saas/script/configure-lb-*.sh), which is what fixes the
#  proxy access logs the app tier ships. This middleware is kept because it also covers the app
#  when it is reached without going through that load balancer, and because it collapses the
#  forwarded chain to the one address we actually trust.
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
