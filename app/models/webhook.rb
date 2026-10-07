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

  # Who set the webhook up, and through which app if an OAuth grant did it for
  # them. A webhook is an account resource whoever creates it, so one an app
  # creates outlives the app's grant: it stays, attributed, and the person may
  # remove it when they disconnect the app (My::ConnectedAppsController).
  belongs_to :creator, class_name: "User", optional: true, default: -> { Current.user }
  belongs_to :created_via, class_name: "Oauth::Client", optional: true, default: -> { Current.access_token&.oauth_client }

  serialize :subscribed_actions, type: Array, coder: JSON

  scope :ordered, -> { order(name: :asc, id: :desc) }
  scope :active, -> { where(active: true) }

  # Webhooks an app set up for this identity, in any active account where the
  # person can still manage webhooks.
  scope :set_up_through, ->(client, identity:) do
    where(created_via: client, creator: identity.users.admin.joins(:account).merge(Account.active))
  end

  after_create :create_delinquency_tracker!

  normalizes :subscribed_actions, with: ->(value) { Array.wrap(value).map(&:to_s).uniq & PERMITTED_ACTIONS }
  normalizes :url, with: -> { it.strip }

  validates :name, presence: true
  validate :validate_url

  def activate
    update! active: true unless active?
  end

  def deactivate
    update! active: false
  end

  def renderer
    @renderer ||= ApplicationController.renderer.new(script_name: account.slug, https: !Rails.env.local?)
  end

  def for_basecamp?
    url.match? BASECAMP_CAMPFIRE_WEBHOOK_URL_REGEX
  end

  def for_campfire?
    url.match? CAMPFIRE_WEBHOOK_URL_REGEX
  end

  def for_slack?
    url.match? SLACK_WEBHOOK_URL_REGEX
  end

  private
    def validate_url
      uri = URI.parse(url.presence)

      if PERMITTED_SCHEMES.exclude?(uri.scheme)
        errors.add :url, "must use #{PERMITTED_SCHEMES.to_choice_sentence}"
      end
    rescue URI::InvalidURIError
      errors.add :url, "not a URL"
    end
end
