json.cache! [ event, event.creator, event.eventable ] do
  json.(event, :id, :action)
  json.created_at event.created_at.utc

  json.creator do
    json.id event.creator_id
    json.name event.creator.name
  end

  json.eventable do
    json.type event.eventable_type
    json.id event.eventable_id
    json.url polymorphic_url(event.eventable)
  end
end
