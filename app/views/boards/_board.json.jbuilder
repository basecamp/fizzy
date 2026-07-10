json.cache! board do
  json.(board, :id, :name, :all_access)
  json.created_at board.created_at.utc
  json.auto_postpone_period_in_days board.auto_postpone_period_in_days
  json.url board_url(board)

  json.creator board.creator, partial: "users/user", as: :user

  if board.published?
    json.public_description board.public_description.to_plain_text
    json.public_description_html board.public_description.to_s
    json.public_url published_board_url(board)
  end
end
