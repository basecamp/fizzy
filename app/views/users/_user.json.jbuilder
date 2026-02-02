json.cache! user do
  json.(user, :id, :name, :role, :active)

  json.email_address user.identity&.email_address
  json.created_at user.created_at.utc

  json.url user_url(user)
end
