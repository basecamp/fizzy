class Watch < ApplicationRecord
  belongs_to :account, default: -> do
    # @type self: Watch
    user.account
  end
  belongs_to :user
  belongs_to :card, touch: true

  scope :watching, -> { where(watching: true) }
  scope :not_watching, -> { where(watching: false) }
end
