json.cache! @event do
  json.(@event, :id, :action)
  json.created_at @event.created_at.utc

  json.eventable do
    case @event.eventable
    when Card
      # 1. Load the standard card data (includes basics + url)
      json.partial! "cards/card", card: @event.eventable
      
      # 2. Add the Card Description (Rich Text converted to HTML string)
      # .to_s ensures we get the HTML safely
      json.description @event.eventable.description.to_s

      # 3. Add Assignee Names
      # We map strictly to names to keep the payload clean
      json.assignees @event.eventable.assignees.map(&:name)

      # 4. Add List of Comments (Optimized)
      # PERFORMANCE FIX: We use .includes(:creator, :rich_text_body) to prevent 
      # the "N+1 query problem". This loads all user and text data in 1 go 
      # instead of hitting the database 100 times for 100 comments.
      comments = @event.eventable.comments.includes(:creator, :rich_text_body).order(:created_at)

      json.comments comments do |comment|
        json.user comment.creator.name
        json.text comment.body.to_plain_text # Best for reading in automation (n8n/Zapier)
        json.html comment.body.to_s          # Best for displaying in a dashboard
      end

    when Comment
      # 1. Load the standard comment data
      json.partial! "cards/comments/comment", comment: @event.eventable

      # 2. Add the Comment Content as 'description' for consistency
      json.description @event.eventable.body.to_s
    end
  end

  json.board do
    json.partial! "boards/board", locals: { board: @event.board }
  end

  json.creator do
    json.partial! "users/user", user: @event.creator
  end
end
