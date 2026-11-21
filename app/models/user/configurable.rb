module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy
    has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

    after_create :create_settings, unless: -> { system? || bot? }

    delegate :timezone, to: :settings, allow_nil: true
  end

  def in_time_zone(&block)
    Time.use_zone(timezone, &block)
  end
end
