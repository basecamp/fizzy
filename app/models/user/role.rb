module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ admin member system ].index_by(&:itself), scopes: false

    scope :member, -> { where(role: :member) }
    scope :active, -> { where(active: true, role: %i[ admin member ]) }
  end

  class_methods do
    def system
      find_or_create_by!(role: :system) { it.name = "System" }
    end
  end

  def can_change?(other)
    admin? || other == self
  end

  def can_administer?(other)
    admin? && other != self
  end

  def can_administer_board?(board)
    admin? || board.creator == self
  end

  def can_administer_card?(card)
    admin? || card.creator == self
  end
end
