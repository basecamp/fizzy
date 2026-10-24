module Card::Statuses
  extend ActiveSupport::Concern

  included do
    enum :status, %w[ drafted published ].index_by(&:itself)

    before_save :mark_if_just_published
    before_validation :build_blank_description, if: :drafted?
    after_create -> { track_event :published }, if: :published?
  end

  attr_accessor :was_just_published
  alias_method :was_just_published?, :was_just_published

  def publish
    transaction do
      self.created_at = Time.current
      published!
      track_event :published
    end
  end

  private
    # A draft saves its description as you type, and two saves in flight together each inserted the
    # card's first rich text: the unique index refused the second, and its keystrokes were lost
    # (FIZZY-Z2). Saved with the draft, the row is there before any autosave, which then updates it.
    def build_blank_description
      build_rich_text_description unless rich_text_description
    end

    def mark_if_just_published
      self.was_just_published = true if published? && status_changed?
    end
end
