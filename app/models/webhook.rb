# rbs_inline: enabled

class Webhook < ApplicationRecord
  include Triggerable

  SLACK_WEBHOOK_URL_REGEX = %r{//hooks\.slack\.com/services/T[^\/]+/B[^\/]+/[^\/]+\Z}i
  CAMPFIRE_WEBHOOK_URL_REGEX = %r{/rooms/\d+/\d+-[^\/]+/messages\Z}i
  BASECAMP_CAMPFIRE_WEBHOOK_URL_REGEX = %r{/\d+/integrations/[^\/]+/buckets/\d+/chats/\d+/lines\Z}i

  PERMITTED_SCHEMES = %w[ http https ].freeze
  PERMITTED_ACTIONS = %w[
    card_assigned
    card_closed
    card_postponed
    card_auto_postponed
    card_board_changed
    card_published
    card_reopened
    card_sent_back_to_triage
    card_triaged
    card_unassigned
    comment_created
  ].freeze

  has_secure_token :signing_secret

  has_many :deliveries, dependent: :delete_all
  has_one :delinquency_tracker, dependent: :delete

  belongs_to :account, default: -> { board.account }
  belongs_to :board

  serialize :subscribed_actions, type: Array, coder: JSON

  scope :ordered, -> { order(name: :asc, id: :desc) }
  scope :active, -> { where(active: true) }

  after_create :create_delinquency_tracker!

  normalizes :subscribed_actions, with: ->(value) { Array.wrap(value).map(&:to_s).uniq & PERMITTED_ACTIONS }

  validates :name, presence: true
  validate :validate_url

  #: -> void
  def activate
    update! active: true unless active?
  end

  #: -> void
  def deactivate
    update! active: false
  end

  def renderer
    @renderer ||= ApplicationController.renderer.new(script_name: account.slug, https: !Rails.env.local?)
  end

  #: -> bool
  def for_basecamp?
    url.match? BASECAMP_CAMPFIRE_WEBHOOK_URL_REGEX
  end

  #: -> bool
  def for_campfire?
    url.match? CAMPFIRE_WEBHOOK_URL_REGEX
  end

  #: -> bool
  def for_slack?
    url.match? SLACK_WEBHOOK_URL_REGEX
  end

  private
    #: -> void
    def validate_url
      add_error_not_a_url and return if url.blank?

      uri = URI.parse(url)

      if PERMITTED_SCHEMES.exclude?(uri.scheme)
        errors.add :url, "must use #{PERMITTED_SCHEMES.to_choice_sentence}"
      end
    rescue URI::InvalidURIError
      add_error_not_a_url
    end

    #: -> void
    def add_error_not_a_url
      errors.add :url, "not a URL"
    end
end
