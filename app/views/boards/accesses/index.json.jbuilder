json.board_id @board.id
json.all_access @board.all_access?

json.users @page.records do |user|
  json.partial! "users/user", user: user
  json.has_access involvement_by_user.key?(user.id)
  json.involvement involvement_by_user[user.id]
end
