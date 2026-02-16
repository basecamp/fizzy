# rbs_inline: enabled

class MagicLink < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :identity

  enum :purpose, %w[ sign_in sign_up ], prefix: :for, default: :sign_in

  scope :active, -> { where(expires_at: Time.current...) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code, uniqueness: true, presence: true

  class << self
    #: (String) -> MagicLink?
    def consume(code)
      active.find_by(code: Code.sanitize(code))&.consume
    end

    #: -> void
    def cleanup
      stale.delete_all
    end
  end

  #: -> self
  def consume
    destroy
    self
  end

  private

    #: -> void
    def generate_code
      self.code ||= loop do
        candidate = Code.generate(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end

    #: -> void
    def set_expiration
      self.expires_at ||= EXPIRATION_TIME.from_now
    end
end
