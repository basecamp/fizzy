json.cache! board do
  json.(board, :id, :name, :all_access)
  json.created_at board.created_at.utc

  json.creator do
    json.partial! "users/user", user: board.creator
  end
end
