module Bubble::Commentable
  extend ActiveSupport::Concern

  included do
    scope :ordered_by_comments, -> { order comments_count: :desc }
  end

  def comment_created(comment)
    increment! :comments_count
    watch_by comment.creator

    track_event :commented, comment_id: comment.id
    rescore
  end

  def comment_destroyed
    decrement! :comments_count
    rescore
  end
end
