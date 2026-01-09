# rbs_inline: enabled

module Webhook::Triggerable
  extend ActiveSupport::Concern

  # @type module: singleton(Webhook) & singleton(Webhook::Triggerable)
  # @type instance: Webhook & Webhook::Triggerable

  included do
    scope :triggered_by, ->(event) { where(board: event.board).triggered_by_action(event.action) }
    scope :triggered_by_action, ->(action) { where("subscribed_actions LIKE ?", "%\"#{action}\"%") }
  end

  def trigger(event)
    deliveries.create!(event: event)
  end
end
