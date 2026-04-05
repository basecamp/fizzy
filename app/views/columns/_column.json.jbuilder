json.cache! column do
  json.(column, :id, :name, :color)
  json.created_at column.created_at.utc
  json.cards_url board_column_cards_url(column.board, column)
end
