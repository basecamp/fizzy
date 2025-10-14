json.cache! collection do
  json.(collection, :id, :name, :all_access)
  json.created_at collection.created_at.utc

  json.creator do
    json.partial! "users/user", user: collection.creator
  end
end
