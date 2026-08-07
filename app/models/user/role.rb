module User::Role
  extend ActiveSupport::Concern

  included do
    enum :role, %i[ owner admin member system bot ].index_by(&:itself), scopes: false

    scope :owner, -> { where(active: true, role: :owner) }
    scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
    scope :member, -> { where(active: true, role: :member) }
    scope :bot, -> { where(active: true, role: :bot) }
    scope :active, -> { where(active: true, role: %i[ owner admin member bot ]) }

    def admin?
      super || owner?
    end
  end

  def can_change?(other)
    (admin? && !other.owner?) || other == self
  end

  def can_administer?(other)
    admin? && !other.owner? && other != self
  end

  def can_administer_board?(board)
    admin? || board.creator == self
  end

  def can_administer_card?(card)
    admin? || card.creator == self
  end
end
