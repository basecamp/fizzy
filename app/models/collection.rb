class Collection < ApplicationRecord
  include AutoClosing, Accessible, Broadcastable, Entropic, Filterable, Publishable, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_rich_text :public_description

  has_many :cards, dependent: :destroy
  has_many :tags, -> { distinct }, through: :cards
  has_many :events
  has_many :webhooks, dependent: :destroy
  has_one :entropy_configuration, class_name: "Entropy::Configuration", as: :container, dependent: :destroy

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }

  after_destroy_commit :ensure_default_collection

  private
    def ensure_default_collection
      if Collection.count.zero?
        Collection.create!(name: "Cards")
      end
    end
end
