json.partial! "boards/board", board: @board
json.user_ids @board.users.ids unless @board.all_access?
