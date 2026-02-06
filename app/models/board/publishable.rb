module Board::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, class_name: "Board::Publication", dependent: :destroy
    scope :published, -> { joins(:publication) }
  end

  class_methods do
    def find_by_published_key(key)
      Board::Publication.find_by!(key: key).board
    end
  end

  def published?
    publication.present?
  end
  alias_method :publicly_accessible?, :published?

  def publish
    create_publication! unless published?
  end

  def unpublish
    publication&.destroy
  end
end
