class Notification::Bundle < ApplicationRecord
  belongs_to :account, default: -> { user.account }
  belongs_to :user

  enum :status, %i[ pending processing delivered ]

  scope :due, -> { pending.where("ends_at <= ?", Time.current) }
  scope :containing, ->(notification) { where("starts_at <= ? AND ends_at > ?", notification.updated_at, notification.updated_at) }
  scope :overlapping_with, ->(other_bundle) do
    where(
      "(starts_at <= ? AND ends_at >= ?) OR (starts_at <= ? AND ends_at >= ?) OR (starts_at >= ? AND ends_at <= ?)",
      other_bundle.starts_at, other_bundle.starts_at,
      other_bundle.ends_at, other_bundle.ends_at,
      other_bundle.starts_at, other_bundle.ends_at
    )
  end

  before_validation :set_default_window, if: :new_record?

  validate :validate_no_overlapping

  class << self
    def deliver_all
      due.in_batches do |batch|
        jobs = batch.collect { DeliverJob.new(it) }
        ActiveJob.perform_all_later jobs
      end
    end

    def deliver_all_later
      DeliverAllJob.perform_later
    end
  end

  def notifications
    user.notifications.where(updated_at: window).unread
  end

  def deliver
    user.in_time_zone do
      Current.with_account(user.account) do
        processing!

        Notification::BundleMailer.notification(self).deliver if deliverable?

        delivered!
      end
    end
  end

  def deliver_later
    DeliverJob.perform_later(self)
  end

  def flush
    update!(ends_at: Time.current)
    deliver_later
  end

  def set_default_window
    self.starts_at ||= Time.current
    self.ends_at ||= self.starts_at + user.settings.bundle_aggregation_period
  end

  private
    def window
      starts_at..ends_at
    end

    def validate_no_overlapping
      if overlapping_bundles.exists?
        errors.add(:base, "Bundle window overlaps with an existing pending bundle with id #{overlapping_bundles.first.id}")
      end
    end

    def deliverable?
      user.settings.bundling_emails? && notifications.any? && account.active?
    end

    def overlapping_bundles
      user.notification_bundles.where.not(id: id).overlapping_with(self)
    end
end
