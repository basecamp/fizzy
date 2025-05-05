module Do
  class Parser < AbstractParser
    def parse
      command
    end

    private

    def command
      options do
        maybe { help_command } ||
        maybe { goto_command } ||
        maybe { filter_tag_command } ||
        maybe { assign_card_command } ||
        maybe { tag_card_command } ||
        maybe { close_card_command } ||
        maybe { search_command }
      end
    end

    def help_command
      command = options do
        maybe { consume_command_name("?") } ||
        maybe { consume_command_name("help") } ||
        maybe { consume_command_name("man") }
      end
      HelpCommand.new(command:)
    end

    def goto_command
      options do
        maybe { Do::GotoCommand.new(value: consume(PersonReferenceToken)) } ||
        maybe { Do::GotoCommand.new(value: consume_card_reference) }
      end
    end

    def filter_tag_command
      tags = one_or_more { consume(TagNameToken) }
      FilterTagCommand.new(tags:)
    end

    def assign_card_command
      command = options do
        maybe { consume_command_name("assign") } ||
        maybe { consume_command_name("assignto") }
      end
      consume_whitespace
      people = one_or_more { consume(PersonReferenceToken) }
      AssignCardCommand.new(command:, people:)
    end

    def tag_card_command
      command = consume_command_name("tag")
      consume_whitespace
      tags = one_or_more do
        options do
          maybe { consume(TagNameToken) } || maybe { consume(StringToken) }
        end
      end
      TagCardCommand.new(command:, tags:)
    end

    def close_card_command
      command = consume_command_name("close")
      consume_whitespace
      cards = one_or_more { consume_card_reference }
      reason = maybe { consume(StringToken) }
      CloseCardCommand.new(command:, cards:, reason:)
    end

    def search_command
      terms = one_or_more { consume(StringToken) }
      SearchCommand.new(terms:)
    end

    # We could detect integers in the tokenizer, but right now the grammar only treats it as a card
    # reference if it's the first and only token, so I'm doing that check here instead of
    # introducing an IntegerToken that ends up getting treated like a string if it's not in the
    # first position.
    def consume_card_reference
      result = consume(StringToken)
      raise MissingTokenError unless result.value =~ /\A\d+\z/

      CardReference.new(value: Integer(result.value))
    end

    def consume_command_name(name)
      result = consume(CommandNameToken)
      raise MissingTokenError unless result.value == name

      result
    end
  end

  # --- AST nodes ---
  CardReference = Struct.new(:value)

  AssignCardCommand = Struct.new(:command, :people)
  CloseCardCommand  = Struct.new(:command, :cards, :reason)
  FilterTagCommand  = Struct.new(:command, :tags)
  GotoCommand       = Struct.new(:command, :value)
  HelpCommand       = Struct.new(:command)
  SearchCommand     = Struct.new(:command, :terms)
  TagCardCommand    = Struct.new(:command, :tags)
end
