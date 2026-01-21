class Notification < ApplicationRecord
  include Notification::Pushable

  belongs_to :account, default: -> { user.account }
  belongs_to :user
  belongs_to :creator, class_name: "User"
  belongs_to :source, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, created_at: :desc) }

  after_create_commit :broadcast_unread
  after_destroy_commit :broadcast_read
  after_create :bundle

  scope :preloaded, -> { preload(:creator, :account, source: [ :board, :creator, { eventable: [ :closure, :board, :assignments ] } ]) }

  delegate :notifiable_target, to: :source
  delegate :card, to: :source
  delegate :identity, to: :user

  def self.read_all
    all.each { |notification| notification.read }
  end

  def read
    update!(read_at: Time.current)
    broadcast_read
  end

  def unread
    update!(read_at: nil)
    broadcast_unread
  end

  def read?
    read_at.present?
  end

  private
    def broadcast_unread
      broadcast_prepend_later_to user, :notifications, target: "notifications"
    end

    def broadcast_read
      broadcast_remove_to user, :notifications
    end

    def bundle
      user.bundle(self) if user.settings.bundling_emails?
    end
end
