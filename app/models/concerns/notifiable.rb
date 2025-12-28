# rbs_inline: enabled

module Notifiable
  extend ActiveSupport::Concern

  # @type self: singleton(ActiveRecord::Base) & singleton(Notifiable)

  included do
    has_many :notifications, as: :source, dependent: :destroy

    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    Notifier.for(self)&.notify
  end

  def notifiable_target
    self
  end

  private
    def notify_recipients_later
      NotifyRecipientsJob.perform_later self
    end
end
