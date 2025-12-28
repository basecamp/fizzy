# rbs_inline: enabled

class Search::Result < ApplicationRecord
  attribute :card_id, :uuid
  attribute :comment_id, :uuid
  attribute :creator_id, :uuid

  belongs_to :creator, class_name: "User"
  belongs_to :card, foreign_key: :card_id, optional: true
  belongs_to :comment, foreign_key: :comment_id, optional: true

  def card_title
    highlight(card.title, show: :full) if card_id
  end

  def card_description
    highlight(card.description.to_plain_text, show: :snippet) if card_id
  end

  def comment_body
    highlight(comment.body.to_plain_text, show: :snippet) if comment_id
  end

  def source
    comment_id.present? ? comment : card
  end

  def readonly?
    true
  end

  private
    def highlight(text, show:)
      if text.present? && attribute?(:query)
        highlighter = Search::Highlighter.new(query)
        show == :snippet ? highlighter.snippet(text) : highlighter.highlight(text)
      else
        text
      end
    end
end
