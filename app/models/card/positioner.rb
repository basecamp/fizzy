class Card::Positioner
  STEP = 1024

  def initialize(relation:, fallback_order:)
    @relation = relation
    @fallback_order = fallback_order
  end

  def reposition!(card:, before_number:, after_number:)
    ensure_positions!

    before_card = resolve_neighbor(before_number)
    after_card = resolve_neighbor(after_number)

    new_position = compute_position(before_card:, after_card:)

    # If we can't fit between neighbors, repack and try once more.
    if new_position.nil?
      renumber_all!
      before_card = resolve_neighbor(before_number)
      after_card = resolve_neighbor(after_number)
      new_position = compute_position(before_card:, after_card:) || top_position
    end

    card.update!(position: new_position)
  end

  private
    attr_reader :relation, :fallback_order

    def ensure_positions!
      return unless relation.where(position: nil).exists?

      renumber_all!(use_fallback_order: true)
    end

    def resolve_neighbor(number)
      return nil unless number.present?

      card_number = Integer(number)
      neighbor = relation.find_by(number: card_number)
      return nil unless neighbor

      relation.where(id: neighbor.id).exists? ? neighbor : nil
    rescue ArgumentError
      nil
    end

    def compute_position(before_card:, after_card:)
      return top_position if before_card.nil? && after_card.nil?

      if before_card && after_card
        before_pos = before_card.position
        after_pos = after_card.position
        return nil if before_pos.nil? || after_pos.nil?

        gap = before_pos - after_pos
        return nil if gap <= 1

        return after_pos + (gap / 2)
      end

      return (before_card.position - STEP) if before_card
      return (after_card.position + STEP) if after_card

      nil
    end

    def top_position
      min = relation.where.not(position: nil).minimum(:position)
      min.present? ? (min - STEP) : 0
    end

    def renumber_all!(use_fallback_order: false)
      order_sql = if use_fallback_order
        order_sql_for(fallback_order)
      else
        "cards.position ASC, cards.id ASC"
      end

      ranked = relation
        .reorder(nil)
        .reselect(Arel.sql("cards.id AS id, (ROW_NUMBER() OVER (ORDER BY #{order_sql})) * #{STEP} AS new_position"))

      sql = <<~SQL.squish
        UPDATE cards
        JOIN (#{ranked.to_sql}) ranked ON ranked.id = cards.id
        SET cards.position = ranked.new_position
      SQL

      ActiveRecord::Base.connection.execute(sql)
    end

    def order_sql_for(order)
      case order
      when Hash
        order.map do |column, direction|
          direction_sql = direction.to_s.upcase
          column_sql = column.to_s.include?(".") ? column.to_s : "cards.#{column}"
          "#{column_sql} #{direction_sql}"
        end.join(", ")
      else
        order.to_s
      end
    end
end

