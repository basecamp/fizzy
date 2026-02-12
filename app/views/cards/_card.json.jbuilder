json.cache! card do
  json.(card, :id, :number, :title, :status)
  json.description card.description.to_plain_text
  json.description_html card.description.to_s
  json.image_url card.image.presence && url_for(card.image)
  json.has_attachments card.has_attachments?

  json.tags card.tags.pluck(:title).sort

  json.closed card.closed?
  json.postponed card.postponed?
  json.golden card.golden?
  json.last_active_at card.last_active_at.utc
  json.created_at card.created_at.utc

  json.url card_url(card)

  json.board card.board, partial: "boards/board", as: :board
  json.column card.column, partial: "columns/column", as: :column if card.column
  json.creator card.creator, partial: "users/user", as: :user
  json.assignees card.assignees.limit(5), partial: "users/user", as: :user
  json.has_more_assignees card.assignees.size > 5

  json.comments_url card_comments_url(card)
  json.reactions_url card_reactions_url(card)
end
