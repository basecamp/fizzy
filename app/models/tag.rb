# rbs_inline: enabled

class Tag < ApplicationRecord
  include Attachable, Filterable

  belongs_to :account, default: -> { Current.account }
  has_many :taggings, dependent: :destroy
  has_many :cards, through: :taggings

  validates :title, format: { without: /\A#/ }
  normalizes :title, with: -> { it.downcase }

  scope :alphabetically, -> { order("lower(title)") }
  scope :unused, -> { left_outer_joins(:taggings).where(taggings: { id: nil }) }

  def hashtag
    "#" + title!
  end

  #: -> String
  def title!
    title or raise
  end

  def cards_count
    cards.open.count
  end
end
