class Watch < ApplicationRecord
  belongs_to :user
  belongs_to :card

  scope :watching, -> { where(watching: true) }
  scope :not_watching, -> { where(watching: false) }
end
