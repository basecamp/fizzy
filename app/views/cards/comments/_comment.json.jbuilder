json.cache! comment do
  json.(comment, :id)

  json.created_at comment.created_at.utc
  json.updated_at comment.updated_at.utc

  json.body do
    json.plain_text comment.body.to_plain_text
    json.html comment.body.to_s
  end

  json.body_plain_text comment.body.to_plain_text

  json.mentions comment.mentions.includes(:mentionee) do |mention|
    mentionee = mention.mentionee
    json.user_id mentionee.id
    json.username mentionee.identity&.email_address&.split("@")&.first || mentionee.name.downcase.gsub(/\s+/, ".")
    json.name mentionee.name
    json.email mentionee.identity&.email_address
  end

  json.card_links comment.card_links.includes(:card) do |card_link|
    json.card_id card_link.card.number
    json.title card_link.card.title
  end

  json.creator do
    json.partial! "users/user", user: comment.creator
  end

  json.reactions_url card_comment_reactions_url(comment.card_id, comment.id)
  json.url card_comment_url(comment.card_id, comment.id)
end
