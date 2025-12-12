json.cache! reaction do
  json.(reaction, :id, :content)
  json.reacter reaction.reacter, partial: "users/user", as: :user
  json.url card_comment_reaction_url(reaction.comment.card, reaction.comment, reaction)
end
