module Column::Positioned
  extend ActiveSupport::Concern

  included do
    scope :sorted, -> { order(position: :asc) }

    before_create :set_position
  end

  def move_left
    swap_position_with left_column
  end

  def move_right
    swap_position_with right_column
  end

  def left_column
    board.columns.where("position < ?", position).sorted.last
  end

  def right_column
    board.columns.where("position > ?", position).sorted.first
  end

  def leftmost?
    left_column.nil?
  end

  def rightmost?
    right_column.nil?
  end

  def adjacent_columns
    board.columns.where(id: [ left_column&.id, right_column&.id ].compact)
  end

  private
    def set_position
      max_position = board.columns.maximum(:position) || 0
      self.position = max_position + 1
    end

    def swap_position_with(other_column)
      return if other_column.nil?

      transaction do
        old_position = self.position
        self.update_column(:position, other_column.position)
        other_column.update_column(:position, old_position)
      end
    end
end
