class Comment < ApplicationRecord
  include Messageable, Notifiable, Searchable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :reactions, dependent: :destroy

  searchable_by :body_plain_text, using: :comments_search_index, as: :body

  has_markdown :body

  before_destroy :cleanup_events

  def first_by_author_on_bubble?
    bubble_comments.many? && bubble_comments_prior.where(creator_id: creator_id).none?
  end

  def follows_comment_by_another_author?
    bubble_comments.many? && bubble_comments_prior.last&.creator != creator
  end

  def to_partial_path
    "bubbles/#{super}"
  end

  private
    def cleanup_events
      # Delete events that reference through event_summary
      if message&.event_summary.present?
        Event.where(summary: message.event_summary).destroy_all
      end

      # Delete events that reference directly in particulars
      Event.where(particulars: { comment_id: id }).destroy_all
    end

    def bubble_comments_prior
      bubble_comments.where(created_at: ...created_at)
    end

    def bubble_comments
      Comment.joins(:message).where(messages: { bubble: bubble })
    end
end
