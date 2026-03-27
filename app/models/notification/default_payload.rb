class Notification::DefaultPayload
  attr_reader :notification

  delegate :card, to: :notification

  def initialize(notification)
    @notification = notification
  end

  def to_h
    { title: title, body: body, url: url }
  end

  def title
    "New notification"
  end

  def body
    "You have a new notification"
  end

  def url
    notifications_url
  end

  def category
    "default"
  end

  def high_priority?
    false
  end

  def base_url
    Rails.application.routes.url_helpers.root_url(**url_options.except(:script_name)).chomp("/")
  end

  def avatar_url
    Rails.application.routes.url_helpers.user_avatar_url(notification.creator, **url_options)
  end

  private
    def card_url(card)
      Rails.application.routes.url_helpers.card_url(card, **url_options)
    end

    def notifications_url
      Rails.application.routes.url_helpers.notifications_url(**url_options)
    end

    def url_options
      base_options = Rails.application.routes.default_url_options.presence ||
        Rails.application.config.action_mailer.default_url_options ||
        {}
      base_options.merge(script_name: notification.account.slug)
    end
end
