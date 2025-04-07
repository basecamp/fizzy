module Bubble::Messages
  extend ActiveSupport::Concern

  included do
    has_many :messages, -> { chronologically }, dependent: :destroy
    scope :ordered_by_comments, -> { order comments_count: :desc }
    after_save :capture_draft_comment
  end

  def capture(messageable)
    messages.create! messageable: messageable
  end

  def draft_comment
    find_or_build_initial_comment.body.content
  end

  def draft_comment=(body)
    if body.present?
      @draft_comment = body
    else
      messages.comments.destroy_all
    end
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

  private
    def find_or_build_initial_comment
      message = messages.comments.first || messages.new(messageable: Comment.new)
      message.comment
    end

    def capture_draft_comment
      if @draft_comment.present?
        find_or_build_initial_comment.update! body: @draft_comment, creator: creator
      end
      @draft_comment = nil
    end
end
