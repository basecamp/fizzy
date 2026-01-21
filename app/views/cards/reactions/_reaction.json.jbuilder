json.cache! reaction do
  json.(reaction, :id, :content)
  json.reacter reaction.reacter, partial: "users/user", as: :user
  json.url card_reaction_url(reaction.reactable, reaction)
end
