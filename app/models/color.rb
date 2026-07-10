Color = Struct.new(:name, :value)

class Color
  class << self
    # Finds a Color by its CSS value (e.g. "var(--color-card-4)").
    # Falls back to extracting the value from legacy export formats where
    # the Color struct was serialized instead of the raw CSS string.
    def for_value(value)
      COLORS.find { |it| it.value == value } ||
        extract_from_legacy_export(value)
    end

    private
      # Broken exports serialized Color structs instead of raw CSS values,
      # producing JSON like {"name":"Lime","value":"var(--color-card-4)"}.
      # Parse it and extract the value.
      def extract_from_legacy_export(value)
        parsed = value.is_a?(String) && JSON.parse(value)
        COLORS.find { |it| it.value == parsed["value"] } if parsed.is_a?(Hash)
      rescue JSON::ParserError
      end
  end

  def to_s
    value
  end

  COLORS = {
    "Blue" => "var(--color-card-default)",
    "Gray" => "var(--color-card-1)",
    "Tan" => "var(--color-card-2)",
    "Yellow" => "var(--color-card-3)",
    "Lime" => "var(--color-card-4)",
    "Aqua" => "var(--color-card-5)",
    "Violet" => "var(--color-card-6)",
    "Purple" => "var(--color-card-7)",
    "Pink" => "var(--color-card-8)"
  }.collect { |name, value| new(name, value) }.freeze
end
