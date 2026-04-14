module Card::Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, dependent: :destroy
    has_many :tags, through: :taggings

    scope :tagged_with, ->(tags) { joins(:taggings).where(taggings: { tag: tags }) }

    validate :tags_belong_to_account
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

  private
    def tags_belong_to_account
      return if tags.all? { it.account_id == account_id }

      errors.add(:tags, "must belong to the card account")
    end
end
