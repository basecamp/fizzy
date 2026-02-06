json.cache! board do
  json.(board, :id, :name, :all_access)
  json.created_at board.created_at.utc
  json.url board_url(board)

  json.creator board.creator, partial: "users/user", as: :user
end
