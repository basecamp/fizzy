class SlackItem < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :card
  belongs_to :slack_integration

  validates :slack_message_ts, presence: true, uniqueness: { scope: :slack_integration_id }
  validates :channel_id, presence: true
end
