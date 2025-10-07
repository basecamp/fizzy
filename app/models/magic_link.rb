class MagicLink < UntenantedRecord
  CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :membership

  scope :active, -> { where(expires_at: Time.current...) }
  scope :stale, -> { where(expires_at: ..Time.current) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code, uniqueness: true, presence: true

  class << self
    def consume(code)
      active.find_by(code: sanitize_code(code))&.consume
    end

    def cleanup
      stale.delete_all
    end

    def generate_code(length)
      length.times.map { CODE_ALPHABET.sample }.join
    end

    def sanitize_code(code)
      if code.present?
        sanitized = code.to_s.upcase
        CODE_SUBSTITUTIONS.each { |from, to| sanitized.gsub!(from, to) }
        sanitized.gsub(/[^#{CODE_ALPHABET.join}]/, "")
      else
        nil
      end
    end
  end

  def consume
    destroy
    membership
  end

  private
    def generate_code
      self.code = loop do
        candidate = self.class.generate_code(CODE_LENGTH)
        break candidate unless self.class.exists?(code: candidate)
      end
    end

    def set_expiration
      self.expires_at = EXPIRATION_TIME.from_now
    end
end
