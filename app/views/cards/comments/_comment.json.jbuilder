json.cache! comment do
  json.(comment, :id)

  json.created_at comment.created_at.utc
  json.updated_at comment.updated_at.utc

  json.body do
    json.plain_text comment.body.to_plain_text
    json.html comment.body.to_s
  end

  json.creator comment.creator, partial: "users/user", as: :user

  json.card do
    json.id comment.card_id
    json.url card_url(comment.card)
  end

  json.reactions_url card_comment_reactions_url(comment.card, comment)
  json.url card_comment_url(comment.card, comment)
end
