json.(filter, :id)
json.boards_label filter.boards_label
json.summary filter.summary
json.params filter.as_params
json.created_at filter.created_at.utc
json.updated_at filter.updated_at.utc
json.url filter_url(filter, format: :json)
json.cards_url cards_url(filter_id: filter.id)
