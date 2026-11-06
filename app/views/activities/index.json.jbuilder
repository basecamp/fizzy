json.array! @page.records, partial: "activities/activity", as: :event, cached: ->(event) { activity_cache_key(event) }
