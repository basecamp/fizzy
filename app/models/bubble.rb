class Bubble < ApplicationRecord
  include Assignable, Boostable, Colored, Eventable, Messages, Poppable, Searchable, Staged, Taggable

  belongs_to :bucket, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_one_attached :image, dependent: :purge_later

  before_save :set_default_title

  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
  scope :chronologically, -> { order created_at: :asc, id: :asc }
  scope :in_bucket, ->(bucket) { where bucket: bucket }

  # FIXME: Compute activity and comment count at write time so it's easier to query for.
  scope :left_joins_comments, -> do
    left_joins(:messages).merge(Message.left_joins_messageable(:comments))
  end
  scope :ordered_by_activity, -> do
    left_joins_comments.select("bubbles.*, COUNT(comments.id) + bubbles.boost_count AS activity").group(:id).order("activity DESC")
  end
  scope :ordered_by_comments, -> do
    left_joins_comments.select("bubbles.*, COUNT(comments.id) AS comment_count").group(:id).order("comment_count DESC")
  end

  scope :indexed_by, ->(index) do
    case index
    when "most_active"    then ordered_by_activity
    when "most_discussed" then ordered_by_comments
    when "most_boosted"   then ordered_by_boosts
    when "newest"         then reverse_chronologically
    when "oldest"         then chronologically
    when "popped"         then popped
    end
  end

  def activity_count
    boost_count + messages.comments.size
  end

  private
    def set_default_title
      self.title = title.presence || "Untitled"
    end
end
