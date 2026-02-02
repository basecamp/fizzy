json.cache! tag do
  json.(tag, :id, :title)
  json.created_at tag.created_at.utc
  json.url cards_url(tag_ids: [ tag ])
end
