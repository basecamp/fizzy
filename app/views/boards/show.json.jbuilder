json.partial! "boards/board", board: @board
json.public_description @board.public_description.to_plain_text
json.public_description_html @board.public_description.to_s
json.user_ids @board.users.ids if !@board.all_access?
