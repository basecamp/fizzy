module Card::Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, dependent: :destroy
    has_many :tags, through: :taggings

    scope :tagged_with, ->(tags) { joins(:taggings).where(taggings: { tag: tags }) }
  end

  def tag_ids=(ids)
    ids = Array(ids).compact_blank
    account_scope = account || board&.account || Current.account

    self.tags = ids.present? ? account_scope.tags.find(ids) : []
  end

  def toggle_tag_with(title)
    tag = account.tags.find_or_create_by!(title: title)

    transaction do
      if tagged_with?(tag)
        taggings.destroy_by tag: tag
      else
        taggings.create tag: tag
      end
    end
  end

  def tagged_with?(tag)
    tags.include? tag
  end
end
