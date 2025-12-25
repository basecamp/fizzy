# rbs_inline: enabled

module Card::Stallable
  extend ActiveSupport::Concern

  # @rbs!
  #    extend _ActiveRecord_Relation_ClassMethods[::Card, ::Card::ActiveRecord_Relation, ::String]
  #    extend ::ActiveRecord::Associations::ClassMethods
  #
  #    def activity_spike: -> Card::ActivitySpike
  #
  #    def updated_at: -> ActiveSupport::TimeWithZone
  #    def published?: -> bool
  #    def last_active_at_changed?: -> bool
  #    def open?: -> bool
  #
  #    def self.stalled: -> Card::ActiveRecord_Relation

  STALLED_AFTER_LAST_SPIKE_PERIOD = 14.days

  included do
    # @type self: singleton(Card)
    has_one :activity_spike, class_name: "Card::ActivitySpike", dependent: :destroy

    scope :with_activity_spikes, -> { joins(:activity_spike) }
    scope :stalled, -> { open.active.with_activity_spikes.where("card_activity_spikes.updated_at": ..STALLED_AFTER_LAST_SPIKE_PERIOD.ago, updated_at: ..STALLED_AFTER_LAST_SPIKE_PERIOD.ago) }

    before_update :remember_to_detect_activity_spikes
    after_update_commit :detect_activity_spikes_later, if: :should_detect_activity_spikes?
  end

  #: -> bool?
  def stalled?
    if activity_spike.present?
      open? && last_activity_spike_at&.<(STALLED_AFTER_LAST_SPIKE_PERIOD.ago) && updated_at < STALLED_AFTER_LAST_SPIKE_PERIOD.ago
    end
  end

  #: -> ActiveSupport::TimeWithZone?
  def last_activity_spike_at
    activity_spike&.updated_at
  end

  def detect_activity_spikes
    Card::ActivitySpike::Detector.new(self).detect
  end

  private
    #: -> void
    def remember_to_detect_activity_spikes
      @should_detect_activity_spikes = published? && last_active_at_changed?
    end

    #: -> bool
    def should_detect_activity_spikes?
      @should_detect_activity_spikes
    end

    #: -> void
    def detect_activity_spikes_later
      Card::ActivitySpike::DetectionJob.perform_later(self)
    end
end
