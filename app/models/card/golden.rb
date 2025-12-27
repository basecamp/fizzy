# rbs_inline: enabled

module Card::Golden
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Golden)

  included do
    has_one :goldness, dependent: :destroy, class_name: "Card::Goldness"

    scope :golden, -> { joins(:goldness) }
    scope :with_golden_first, -> { left_outer_joins(:goldness).prepend_order("card_goldnesses.id IS NULL").preload(:goldness) }
  end

  #: -> bool
  def golden?
    # @type self: Card & Card::Golden
    goldness.present?
  end

  #: -> Card::Goldness?
  def gild
    # @type self: Card & Card::Golden
    create_goldness! unless golden?
  end

  #: -> bool?
  def ungild
    # @type self: Card & Card::Golden
    goldness&.destroy
  end
end
