module Board::Archivable
  extend ActiveSupport::Concern

  included do
    has_one :archival, class_name: "Board::Archival", dependent: :destroy

    scope :archived, -> { joins(:archival) }
    scope :active, -> { where.missing(:archival) }
  end

  def archived?
    archival.present?
  end

  def archived_by
    archival&.user
  end

  def archived_at
    archival&.created_at
  end

  def archive(user: Current.user)
    unless archived?
      transaction do
        create_archival!(user: user)
        touch_contents
      end
    end
  end

  def unarchive
    if archived?
      transaction do
        archival.destroy
        touch_contents
      end
    end
  end

  private
    # Cards, columns and comments render their edit controls inside fragments cached on their
    # own keys, so they need new keys when the board becomes read-only or writable again.
    def touch_contents
      cards.touch_all
      columns.touch_all
      Comment.where(card: cards).touch_all
    end
end
