json.cache! reaction do
  json.(reaction, :id, :content)
  json.reacter reaction.reacter, partial: "users/user", as: :user
  json.url polymorphic_url([ *reaction_path_prefix_for(reaction.reactable), reaction ])
end
