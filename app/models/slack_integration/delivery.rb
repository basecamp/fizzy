class SlackIntegration::Delivery < ApplicationRecord
  STALE_THRESHOLD = 7.days

  belongs_to :account, default: -> { slack_integration.account }
  belongs_to :slack_integration

  store :request, coder: JSON
  store :response, coder: JSON

  enum :state, %w[ pending processed errored ].index_by(&:itself), default: :pending

  scope :ordered, -> { order created_at: :desc, id: :desc }
  scope :stale, -> { where(created_at: ...STALE_THRESHOLD.ago) }

  def self.cleanup
    stale.delete_all
  end

  def succeeded?
    processed? && response[:error].blank?
  end

  def failed?
    errored? || (processed? && response[:error].present?)
  end

  def record_success
    update!(state: :processed, response: { success: true })
  end

  def record_error(error_message)
    update!(state: :errored, response: { error: error_message })
  end
end
