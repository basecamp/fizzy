module Messageable
  extend ActiveSupport::Concern

  TYPES = %w[ Comment EventSummary ]

  included do
    has_one :message, as: :messageable, touch: true, dependent: :destroy
    has_one :card, through: :message
  end
end
