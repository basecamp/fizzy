json.cache! [ card, card.column&.color ] do
  json.(card, :id, :title, :status)
  json.image_url card.image.presence && url_for(card.image)

  json.golden card.golden?
  json.last_active_at card.last_active_at.utc
  json.created_at card.created_at.utc

  json.url card_url(card)

  json.collection do
    json.partial! "collections/collection", locals: { collection: card.collection }
  end

  json.column do
    if card.column
      json.partial! "columns/column", column: card.column
    else
      nil
    end
  end

  json.creator do
    json.partial! "users/user", user: card.creator
  end
end
