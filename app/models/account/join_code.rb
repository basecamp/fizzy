class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12
  USAGE_LIMIT_MAX = 10_000_000_000

  belongs_to :account

  validates :usage_limit, numericality: { less_than_or_equal_to: USAGE_LIMIT_MAX, message: "cannot be larger than the population of the planet" }

  scope :active, -> { where("usage_count < usage_limit") }

  before_create :generate_code, if: -> { code.blank? }

  # with_lock reloads the row, so a reset that lands between finding this code
  # and taking the lock shows up as a different code here, and the stale one
  # is refused rather than redeemed against the reset's fresh usage count.
  def redeem_if(&block)
    redeemed_code = code

    with_lock do
      increment!(:usage_count) if code == redeemed_code && active? && block.call(account)
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
