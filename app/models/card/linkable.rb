module Card::Linkable
  extend ActiveSupport::Concern

  included do
    has_many :outgoing_links, class_name: "CardLink",
             foreign_key: :source_card_id, dependent: :destroy
    has_many :incoming_links, class_name: "CardLink",
             foreign_key: :target_card_id, dependent: :destroy
  end

  # Return ActiveRecord::Relations for chainability (not arrays)
  def parents
    Card.where(id: outgoing_links.parent.select(:target_card_id))
  end

  def children
    Card.where(id: outgoing_links.child.select(:target_card_id))
  end

  def related_cards
    Card.where(id: outgoing_links.related.select(:target_card_id))
  end

  def linked_cards
    Card.where(id: outgoing_links.select(:target_card_id))
  end

  def linking_cards
    Card.where(id: incoming_links.select(:source_card_id))
  end

  def has_links?
    outgoing_links.exists? || incoming_links.exists?
  end

  # Toggle-style API (matches Card::Taggable pattern)
  def toggle_link(target_card, link_type: :related)
    existing = outgoing_links.find_by(target_card: target_card, link_type: link_type)
    if existing
      existing.destroy
      :removed
    else
      outgoing_links.create!(target_card: target_card, link_type: link_type)
      :added
    end
  end
end
