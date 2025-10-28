class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12

  scope :active, -> { where("usage_count < usage_limit") }

  before_validation :generate_code, on: :create, if: -> { code.blank? }

  validates :code, presence: true, uniqueness: true
  validates :usage_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :usage_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def redeem
    transaction do
      increment!(:usage_count)
      yield if block_given?
    end
  end

  def active?
    usage_count < usage_limit
  end

  def reset
    generate_code
    self.usage_count = 0
    save!
  end

  private
    def generate_code
      self.code = loop do
        candidate = SecureRandom.base58(CODE_LENGTH).scan(/.{4}/).join("-")
        break candidate unless self.class.exists?(code: candidate)
      end
    end
end
