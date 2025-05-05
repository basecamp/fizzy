module Do
  class MissingTokenError < StandardError
  end

  class AbstractParser
    # A custom enumerator around the list of tokens. This allows us to implement "maybe" with a
    # simple transation/rollback construct.
    class TokenEnumerator
      class Rollback < StandardError
      end

      attr_reader :tokens, :index

      def initialize(tokens)
        @tokens = tokens.to_a
        @index = 0
      end

      def next
        peek.tap { @index += 1 }
      end

      def peek
        @tokens[@index]
      end

      def transaction
        saved = @index
        yield
      rescue Rollback
        @index = saved
        nil
      end
    end

    attr_reader :tokens

    def initialize(tokens)
      @tokens = TokenEnumerator.new(tokens)
    end

    private

    def consume(*values, case_insensitive: false)
      result =
        values.map do |value|
        case [ value, tokens.peek ]
        in [Class, token] if token.is_a?(value)
          tokens.next
        in [_, token]
          raise MissingTokenError, "Expected #{value} but got #{token.inspect}"
        end
      end

      result.size == 1 ? result.first : result
    end

    def consume_whitespace
      while tokens.peek.is_a?(WhitespaceToken)
        tokens.next
      end
    end

    def maybe
      tokens.transaction do
        yield
      rescue MissingTokenError
        raise TokenEnumerator::Rollback
      end
    end

    def options
      value = yield
      raise MissingTokenError, "Expected one of many to match" if value.nil?

      value
    end

    def one_or_more
      items = []

      consume_whitespace
      items << yield

      loop do
        consume_whitespace
        if (item = maybe { yield })
          items << item
        else
          return items
        end
      end
    end
  end
end
