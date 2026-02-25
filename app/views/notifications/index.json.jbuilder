json.array! (@unread || []) + @page.records, partial: "notifications/notification", as: :notification, cached: true
