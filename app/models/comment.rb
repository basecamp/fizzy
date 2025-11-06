class Comment < ApplicationRecord
  include Attachments, Eventable, Mentions, Promptable, Searchable
  belongs_to :card, touch: true

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :reactions, dependent: :delete_all

  has_rich_text :body
  searchable_by :body, using: :comments_search_index

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :by_system, -> { joins(:creator).where(creator: { role: "system" }) }
  scope :by_user, -> { joins(:creator).where.not(creator: { role: "system" }) }

  after_create_commit :watch_card_by_creator

  delegate :board, :watch_by, to: :card

  def to_partial_path
    "cards/#{super}"
  end

  private
    def watch_card_by_creator
      card.watch_by creator
    end
end
