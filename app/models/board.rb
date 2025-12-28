# rbs_inline: enabled

class Board < ApplicationRecord
  include AutoPostponing, Broadcastable, Entropic, Filterable, Publishable, Triageable
  include Accessible
  include Cards

  # @rbs!
  #   class ::Access::ActiveRecord_Associations_CollectionProxy < ::ActiveRecord::Associations::CollectionProxy
  #     def grant_to: (User::ActiveRecord_Relation | User::ActiveRecord_Associations_CollectionProxy) -> void
  #
  #     def revoke_from: (User::ActiveRecord_Relation | User::ActiveRecord_Associations_CollectionProxy) -> void
  #   end
  #

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
