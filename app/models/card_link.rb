class CardLink < ApplicationRecord
  enum :link_type, { related: 0, parent: 1, child: 2 }

  belongs_to :source_card, class_name: "Card", touch: true
  belongs_to :target_card, class_name: "Card", touch: true

  validates :source_card_id, uniqueness: { scope: [:target_card_id, :link_type] }
  validate :no_self_links
  validate :same_account
  validate :no_circular_parent_chain, if: :parent?

  # Derive account from source_card (not stored)
  def account
    source_card&.account
  end

  private
    def no_self_links
      errors.add(:target_card, "cannot link to itself") if source_card_id == target_card_id
    end

    def same_account
      return if source_card&.account_id == target_card&.account_id
      errors.add(:target_card, "must be in the same account")
    end

    def no_circular_parent_chain
      # BFS to detect cycles through ALL parent paths
      return unless parent?

      visited = Set.new
      queue = [target_card_id]

      while (current_id = queue.shift)
        return errors.add(:target_card, "would create circular parent chain") if current_id == source_card_id
        next if visited.include?(current_id)

        visited << current_id

        # Get all parents of current card
        CardLink.where(source_card_id: current_id, link_type: :parent)
                .pluck(:target_card_id)
                .each { |parent_id| queue << parent_id }
      end
    end
end
