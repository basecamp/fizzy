module Card::Statuses
  extend ActiveSupport::Concern

  included do
    enum :status, %w[ drafted published ].index_by(&:itself)

    after_create -> { track_event :published }, if: :published?

    scope :published_or_drafted_by, ->(user) { where(status: :published).or(where(status: :drafted, creator: user)) }
  end

  def publish
    transaction do
      published!
      track_event :published
    end
  end
end
