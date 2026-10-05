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
    create_archival!(user: user) unless archived?
  end

  def unarchive
    archival&.destroy
  end
end
