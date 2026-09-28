class Comment < ApplicationRecord
  include Attachments, Eventable, Mentions, Promptable, Storage::Tracked

  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :reactions, -> { order(:created_at) }, as: :reactable, dependent: :delete_all

  has_rich_text :body

  has_search index: :searchable, async: false, if: ->(comment) { comment.card.published? },
    scope: -> { preload(card: [ :board, :creator ]).with_rich_text_body },
    serializer: ->(comment) {
    { account_id: comment.account_id, card_id: comment.card_id, board_id: comment.card.board_id,
      title: nil, content: comment.body.to_plain_text.truncate_bytes(Card::SEARCH_CONTENT_LIMIT, omission: ""),
      created_at: comment.created_at }
  }

  validate :card_is_commentable

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> { with_rich_text_body.includes(reactions: :reacter) }
  scope :by_system, -> { joins(:creator).where(creator: { role: :system }) }
  scope :by_user, -> { joins(:creator).where.not(creator: { role: :system }) }

  after_create_commit :watch_card_by_creator

  delegate :publicly_accessible?, :accessible_to?, :board, :watch_by, to: :card

  def to_partial_path
    "cards/#{super}"
  end

  private
    def card_is_commentable
      errors.add(:card, "does not allow comments") unless card.commentable?
    end

    def watch_card_by_creator
      card.watch_by creator
    end
end
