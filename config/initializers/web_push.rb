require "web-push"
require "web_push/pool"
require "web_push/notification"

Rails.application.configure do
  config.x.web_push_pool = WebPush::Pool.new(
    invalid_subscription_handler: ->(subscription_id) do
      Rails.application.executor.wrap do
        Rails.logger.info "Destroying push subscription: #{subscription_id}"
        Push::Subscription.find_by(id: subscription_id)&.destroy
      end
    end
  )

  at_exit { config.x.web_push_pool.shutdown }
end

module WebPush::PersistentRequest
  def perform
    endpoint_ip = @options[:endpoint_ip]

    if endpoint_ip
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = endpoint_ip
      http.use_ssl = true
      http.ssl_timeout = @options[:ssl_timeout] unless @options[:ssl_timeout].nil?
      http.open_timeout = @options[:open_timeout] unless @options[:open_timeout].nil?
      http.read_timeout = @options[:read_timeout] unless @options[:read_timeout].nil?
    elsif @options[:connection]
      http = @options[:connection]
    else
      http = Net::HTTP.new(uri.host, uri.port, *proxy_options)
      http.use_ssl = true
      http.ssl_timeout = @options[:ssl_timeout] unless @options[:ssl_timeout].nil?
      http.open_timeout = @options[:open_timeout] unless @options[:open_timeout].nil?
      http.read_timeout = @options[:read_timeout] unless @options[:read_timeout].nil?
    end

    req = Net::HTTP::Post.new(uri.request_uri, headers)
    req.body = body

    if http.is_a?(Net::HTTP::Persistent)
      response = http.request uri, req
    else
      resp = http.request(req)
      verify_response(resp)
    end

    resp
  end
end

WebPush::Request.prepend WebPush::PersistentRequest
