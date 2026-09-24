class Board < ApplicationRecord
  include Accessible, AutoPostponing, Board::Storage, Broadcastable, Cards, Entropic, Filterable, Publishable, ::Storage::Tracked, Triageable

  WORK_PLANNING_TIME_LIMIT_OPTIONS_IN_SECONDS = [ 5, 10, 30, 60, 90 ].freeze
  DEFAULT_WORK_PLANNING_TIME_LIMIT_IN_SECONDS = 30

  before_validation { self.work_planning_time_limit_in_seconds ||= DEFAULT_WORK_PLANNING_TIME_LIMIT_IN_SECONDS }

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  has_rich_text :public_description

  has_many :tags, -> { distinct }, through: :cards
  has_many :events
  has_many :webhooks, dependent: :destroy

  validates :work_planning_time_limit_in_seconds, inclusion: { in: WORK_PLANNING_TIME_LIMIT_OPTIONS_IN_SECONDS }

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }
end
