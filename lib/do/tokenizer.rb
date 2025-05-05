module Do
  class Tokenizer
    # Used to communicate between tokenization algorithms.
    class State
      attr_reader :value, :index

      def initialize(value, index)
        @value = value
        @index = index
      end
    end

    WHITESPACE = "[\r\n\t ]"

    attr_reader :source, :errors

    def initialize(source)
      @source = source
      @errors = []
    end

    def tokenize
      Enumerator.new do |enum|
        index = 0

        while index < source.length
          state = consume_token(index)

          enum << state.value
          index = state.index
        end

        enum << EOFToken.new
      end
    end

    private

    def consume_token(index)
      case source[index..]
      when %r{\A/}
        consume_command_name(index + 1)
      when /\A#/
        consume_tag_name(index + 1)
      when /\A@/
        consume_person_reference(index + 1)
      when /\A#{WHITESPACE}+/o
        State.new(WhitespaceToken.new, index + ::Regexp.last_match(0).length)
      else
        consume_string(index)
      end
    end

    def consume_command_name(index)
      value = +""
      while source[index] && !whitespace?(source[index])
        value << source[index]
        index += 1
      end
      State.new(CommandNameToken.new(value: value), index)
    end

    def consume_person_reference(index)
      value = +""
      while source[index] && !whitespace?(source[index])
        value << source[index]
        index += 1
      end
      State.new(PersonReferenceToken.new(value: value), index)
    end

    def consume_tag_name(index)
      value = +""
      while source[index] && !whitespace?(source[index])
        value << source[index]
        index += 1
      end
      State.new(TagNameToken.new(value: value), index)
    end

    def consume_string(index)
      value = +""
      if %q('").include?(source[index])
        quote = source[index]
        index += 1

        while source[index] && source[index] != quote
          value << source[index]
          index += 1
        end

        if source[index] == quote
          index += 1
        else
          errors << ParseError.new("unterminated string at #{start}")
        end
      else
        while source[index] && !whitespace?(source[index])
          value << source[index]
          index += 1
        end
      end

      State.new(StringToken.new(value: value), index)
    end

    def whitespace?(char)
      /#{WHITESPACE}/o.match?(char)
    end
  end

  class EOFToken; end
  class WhitespaceToken; end

  CommandNameToken = Struct.new(:value)
  PersonReferenceToken = Struct.new(:value)
  StringToken = Struct.new(:value)
  TagNameToken = Struct.new(:value)
end
