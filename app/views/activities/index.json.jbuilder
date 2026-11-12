json.array! @activities, partial: "activities/activity", as: :event, cached: ->(event) { [ event, event.card ] }
