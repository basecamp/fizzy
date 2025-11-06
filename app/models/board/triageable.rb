module Board::Triageable
  extend ActiveSupport::Concern

  included do
    has_many :columns, dependent: :destroy
  end
end
