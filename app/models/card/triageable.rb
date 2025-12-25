# rbs_inline: enabled

module Card::Triageable
  extend ActiveSupport::Concern

  # @type module: singleton(Card::Concern)

  included do
    belongs_to :column, optional: true, touch: true

    scope :awaiting_triage, -> { active.where.missing(:column) }
    scope :triaged, -> { active.joins(:column) }
  end

  def triaged?
    # @type self: Card::Concern
    active? && column.present?
  end

  def awaiting_triage?
    # @type self: Card::Concern
    active? && !triaged?
  end

  def triage_into(column)
    # @type self: Card::Concern
    raise "The column must belong to the card board" unless board == column.board

    transaction do
      resume
      update! column: column
      track_event "triaged", particulars: { column: column.name }
    end
  end

  def send_back_to_triage(skip_event: false)
    # @type self: Card::Concern
    transaction do
      resume
      update! column: nil
      track_event "sent_back_to_triage" unless skip_event
    end
  end
end
