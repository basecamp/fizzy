# rbs_inline: enabled

module Card::Postponable
  extend ActiveSupport::Concern

  # @type module: singleton(Card::Concern)

  included do
    has_one :not_now, dependent: :destroy, class_name: "Card::NotNow"

    scope :postponed, -> { open.published.joins(:not_now) }
    scope :active, -> { open.published.where.missing(:not_now) }
  end

  def postponed?
    # @type self: Card::Concern
    open? && published? && not_now.present?
  end

  def postponed_at
    # @type self: Card::Concern
    not_now&.created_at
  end

  def postponed_by
    # @type self: Card::Concern
    not_now&.user
  end

  def active?
    # @type self: Card::Concern
    open? && published? && !postponed?
  end

  def auto_postpone(**args)
    # @type self: Card::Concern
    postpone(**args, event_name: :auto_postponed)
  end

  def postpone(user: Current.user, event_name: :postponed)
    # @type self: Card::Concern
    transaction do
      send_back_to_triage(skip_event: true)
      reopen
      activity_spike&.destroy
      create_not_now!(user: user) unless postponed?
      track_event event_name, creator: user
    end
  end

  def resume
    # @type self: Card::Concern
    transaction do
      reopen
      activity_spike&.destroy
      not_now&.destroy
    end
  end
end
