# rbs_inline: enabled

module Card::Postponable
  extend ActiveSupport::Concern

  # @type module: singleton(Card) & singleton(Card::Postponable)
  # @type instance: Card & Card::Postponable

  included do
    has_one :not_now, dependent: :destroy, class_name: "Card::NotNow"

    scope :postponed, -> { open.published.joins(:not_now) }
    scope :active, -> { open.published.where.missing(:not_now) }
  end

  #: -> bool
  def postponed?
    open? && published? && not_now.present?
  end

  #: -> ActiveSupport::TimeWithZone?
  def postponed_at
    not_now&.created_at
  end

  #: -> User?
  def postponed_by
    not_now&.user
  end

  #: -> bool
  def active?
    open? && published? && !postponed?
  end

  #: (**untyped) -> void
  def auto_postpone(**args)
    postpone(**args, event_name: :auto_postponed)
  end

  #: (?user: User, ?event_name: Symbol) -> void
  def postpone(user: Current.user, event_name: :postponed)
    transaction do
      send_back_to_triage(skip_event: true)
      reopen
      activity_spike&.destroy
      create_not_now!(user: user) unless postponed?
      track_event event_name, creator: user
    end
  end

  #: -> void
  def resume
    transaction do
      reopen
      activity_spike&.destroy
      not_now&.destroy
    end
  end
end
