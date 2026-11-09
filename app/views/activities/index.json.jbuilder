json.array! @page.records, partial: "activities/activity", as: :event, cached: ->(event) { [ event, event.card ] }
