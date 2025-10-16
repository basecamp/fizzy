module MagicLink::Code
  CODE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".chars.freeze
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      length.times.map { CODE_ALPHABET.sample }.join
    end

    def sanitize(code)
      return nil if code.blank?

      normalize_code(code)
        .then { apply_substitutions(_1) }
        .then { remove_invalid_characters(_1) }
    end

    private
      def normalize_code(code)
        code.to_s.upcase
      end

      def apply_substitutions(code)
        CODE_SUBSTITUTIONS.reduce(code) { |result, (from, to)| result.gsub(from, to) }
      end

      def remove_invalid_characters(code)
        code.gsub(/[^#{CODE_ALPHABET.join}]/, "")
      end
  end
end
