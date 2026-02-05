class Account::JoinCode < ApplicationRecord
  CODE_LENGTH = 12
  USAGE_LIMIT_MAX = 10_000_000_000

  belongs_to :account

  validates :usage_limit, numericality: { less_than_or_equal_to: USAGE_LIMIT_MAX, message: -> { I18n.t("activerecord.errors.models.account/join_code.attributes.usage_limit.less_than_or_equal_to") } }

  scope :active, -> { where("usage_count < usage_limit") }

  before_create :generate_code, if: -> { code.blank? }

  def redeem_if(&block)
    with_lock do
      increment!(:usage_count) if active? && block.call(account)
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
