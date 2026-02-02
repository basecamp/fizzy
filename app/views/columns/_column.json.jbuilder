json.cache! column do
  json.(column, :id, :name, :color)
  json.created_at column.created_at.utc
end
