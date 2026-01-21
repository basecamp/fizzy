class Notification < ApplicationRecord
  include Notification::Pushable

  belongs_to :account, default: -> { user.account }
  belongs_to :user
  belongs_to :creator, class_name: "User"
  belongs_to :source, polymorphic: true
  belongs_to :card

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, updated_at: :desc) }
  scope :preloaded, -> {
    preload(
      :creator, :account,
      card: [ :board, :column, :closure, :not_now ],
      source: [ :board, :creator, { eventable: [ :closure, :board, :assignments ] } ]
    )
  }

  before_validation :set_card
  after_create :bundle
  after_update :bundle, if: :source_id_previously_changed?

  after_create_commit  -> { broadcast_prepend_later_to user, :notifications, target: "notifications" }
  after_update_commit  -> { broadcast_update }
  after_destroy_commit -> { broadcast_remove_to user, :notifications }

  delegate :notifiable_target, to: :source
  delegate :identity, to: :user

  class << self
    def read_all
      all.each(&:read)
    end

    def unread_all
      all.each(&:unread)
    end
  end

  def read
    update!(read_at: Time.current, unread_count: 0)
  end

  def unread
    update!(read_at: nil, unread_count: 1)
  end

  def read?
    read_at.present?
  end

  private
    def set_card
      self.card = source.card
    end

    def bundle
      user.bundle(self) if user.settings.bundling_emails?
    end

    def broadcast_update
      if read?
        broadcast_remove_to(user, :notifications)
      else
        broadcast_prepend_later_to(user, :notifications, target: "notifications")
      end
    end
end
