class WebPush::Notification
  def initialize(title:, body:, url:, badge:, endpoint:, endpoint_ip:, p256dh_key:, auth_key:)
    @title, @body, @url, @badge = title, body, url, badge
    @endpoint, @endpoint_ip, @p256dh_key, @auth_key = endpoint, endpoint_ip, p256dh_key, auth_key
  end

  def deliver(connection: nil)
    WebPush.payload_send \
      message: encoded_message,
      endpoint: @endpoint, endpoint_ip: @endpoint_ip, p256dh: @p256dh_key, auth: @auth_key,
      vapid: vapid_identification,
      connection: connection,
      urgency: "high"
  end

  private
    def vapid_identification
      { subject: "mailto:support@fizzy.do" }.merge \
        Rails.configuration.x.vapid.symbolize_keys
    end

    def encoded_message
      JSON.generate title: @title, options: { body: @body, icon: icon_path, data: { url: @url, badge: @badge } }
    end

    def icon_path
      "/apple-touch-icon.png"
    end
end
