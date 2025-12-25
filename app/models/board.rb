# rbs_inline: enabled

class Board < ApplicationRecord
  include AutoPostponing, Broadcastable, Entropic, Filterable, Publishable, Triageable
  include Accessible
  include Cards

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> do
    # @type self: Board
    creator.account
  end

  has_rich_text :public_description

  has_many :tags, -> { distinct }, through: :cards
  has_many :events
  has_many :webhooks, dependent: :destroy

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }
end
