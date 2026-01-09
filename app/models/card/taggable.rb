#rbs_inline: enabled

module Card::Taggable
  extend ActiveSupport::Concern

  # @type self: singleton(Card) & singleton(Card::Taggable)
  # @type instance: Card & Card::Taggable

  included do
    has_many :taggings, dependent: :destroy
    has_many :tags, through: :taggings

    scope :tagged_with, ->(tags) { joins(:taggings).where(taggings: { tag: tags }) }
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
