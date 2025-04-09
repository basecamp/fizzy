class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :event
  belongs_to :card
  belongs_to :resource, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :ordered, -> { order(read_at: :desc, created_at: :desc) }

  delegate :creator, to: :event

  broadcasts_to ->(notification) { [ notification.user, :notifications ] }, inserts_by: :prepend

  class << self
    def read_all
      update!(read_at: Time.current)
    end
  end

  def read?
    read_at.present?
  end
end
