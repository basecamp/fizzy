class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12

  belongs_to :creator, class_name: "User", default: -> { Current.user }

  scope :active, -> { where("usage_count < usage_limit") }

  before_validation :generate_code, on: :create

  validates :code, presence: true, uniqueness: true
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }
  validates :usage_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  class << self
    def redeem(code)
      find_by(code: code)&.tap do |join_code|
        if join_code.active?
          join_code.increment!(:usage_count)
        end
      end
    end

    def active?(code)
      active.exists?(code: code)
    end
  end

  def active?
    usage_count < usage_limit
  end

  private
    def generate_code
      self.code ||= loop do
        candidate = SecureRandom.base58(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end
end
