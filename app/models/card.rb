class Card < ApplicationRecord
  include Assignable, Attachments, Broadcastable, Closeable, Colored, Entropic,
    Eventable, Golden, Mentions, Multistep, Pinnable, Postponable, Promptable,
    Readable, Searchable, Stallable, Statuses, Taggable, Triageable, Watchable

  belongs_to :collection, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :comments, dependent: :destroy
  has_one_attached :image, dependent: :purge_later

  has_rich_text :description

  before_save :set_default_title, if: :published?
  after_update :handle_collection_change, if: :saved_change_to_collection_id?

  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }

  scope :indexed_by, ->(index) do
    case index
    when "stalled" then stalled
    when "postponing_soon" then postponing_soon
    when "closed" then closed.recently_closed_first
    when "not_now" then postponed.latest
    when "golden" then golden
    when "draft" then drafted
    else all
    end
  end

  scope :sorted_by, ->(sort) do
    case sort
    when "newest" then reverse_chronologically
    when "oldest" then chronologically
    when "latest" then latest
    else latest
    end
  end

  delegate :accessible_to?, to: :collection

  def card
    self
  end

  def move_to(new_collection)
    transaction do
      card.update!(collection: new_collection)
      card.events.update_all(collection_id: new_collection.id)
    end
  end

  def filled?
    title.present? || description.present?
  end

  private
    def set_default_title
      self.title = "Untitled" if title.blank?
    end

    def handle_collection_change
      old_collection = Collection.find_by(id: collection_id_before_last_save)

      transaction do
        update! column: nil
        track_collection_change_event(old_collection.name)
        grant_access_to_assignees unless collection.all_access?
      end

      remove_inaccessible_notifications_later
    end

    def track_collection_change_event(old_collection_name)
      track_event "collection_changed", particulars: { old_collection: old_collection_name, new_collection: collection.name }
    end

    def grant_access_to_assignees
      collection.accesses.grant_to(assignees)
    end
end
