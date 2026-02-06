module MagicLink::Code
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      SecureRandom.base32(length)
    end

    def sanitize(code)
      if code.present?
        normalize_code(code)
          .then { apply_substitutions(it) }
          .then { remove_invalid_characters(it) }
      end
    end

    private
      def normalize_code(code)
        code.to_s.upcase
      end

      def apply_substitutions(code)
        CODE_SUBSTITUTIONS.reduce(code) { |result, (from, to)| result.gsub(from, to) }
      end

      def remove_invalid_characters(code)
        code.gsub(/[^#{SecureRandom::BASE32_ALPHABET.join}]/, "")
      end
  end
end
