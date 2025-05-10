class Comment < ApplicationRecord
  include Eventable, Mentions, Searchable
  belongs_to :card, touch: true

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :reactions, dependent: :delete_all

  has_markdown :body
  searchable_by :body_plain_text, using: :comments_search_index, as: :body

  scope :chronologically, -> { order created_at: :asc, id: :desc }

  after_create_commit :watch_card_by_creator

  delegate :collection, :watch_by, to: :card

  def to_partial_path
    "cards/#{super}"
  end

  private
    def watch_card_by_creator
      card.watch_by creator
    end

    def search_embedding_content
      <<~CONTENT
        Card title: #{card.title}
        Content: #{body.to_plain_text}
        Created by: #{creator.name}}
      CONTENT
    end
end
