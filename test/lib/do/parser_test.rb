require "test_helper"

# This test file uses Ruby's pattern matching to make assertions on the structure of the AST parsed
# from the "Fizzy Do" command line.

class DoParserTest < ActiveSupport::TestCase
  test "text search" do
    parse("activity feed performance") do |ast|
      ast => Do::SearchCommand(
        terms: [
          Do::StringToken(value: "activity"),
          Do::StringToken(value: "feed"),
          Do::StringToken(value: "performance"),
        ]
      )
    end

    parse('"activity feed" performance') do |ast|
      ast => Do::SearchCommand(
        terms: [
          Do::StringToken(value: "activity feed"),
          Do::StringToken(value: "performance"),
        ]
      )
    end

    parse("'activity feed' performance") do |ast|
      ast => Do::SearchCommand(
        terms: [
          Do::StringToken(value: "activity feed"),
          Do::StringToken(value: "performance"),
        ]
      )
    end
  end

  test "navigate to person" do
    parse("@mike") { |ast| ast => Do::GotoCommand(value: Do::PersonReferenceToken(value: "mike")) }
    parse("@") { |ast| ast => Do::GotoCommand(value: Do::PersonReferenceToken(value: "")) }
  end

  test "navigate to card" do
    parse("1234") { |ast| ast => Do::GotoCommand(value: Do::CardReference(value: 1234)) }
  end

  test "filter by tag" do
    parse("#low-pri") do |ast|
      ast => Do::FilterTagCommand(tags: [ Do::TagNameToken(value: "low-pri") ])
    end
    parse("#low-pri #quick-win") do |ast|
      ast => Do::FilterTagCommand(
        tags: [ Do::TagNameToken(value: "low-pri"), Do::TagNameToken(value: "quick-win") ],
      )
    end
  end

  test "assign card" do
    # One or more people
    parse("/assign @mike") do |ast|
      ast => Do::AssignCardCommand(
        command: Do::CommandNameToken(value: "assign"),
        people: [ Do::PersonReferenceToken(value: "mike") ],
      )
    end
    parse("/assign @mike @jz") do |ast|
      ast => Do::AssignCardCommand(
        command: Do::CommandNameToken(value: "assign"),
        people: [ Do::PersonReferenceToken(value: "mike"), Do::PersonReferenceToken(value: "jz") ],
      )
    end

    # Alias "assignto"
    parse("/assignto @mike") do |ast|
      ast => Do::AssignCardCommand(
        command: Do::CommandNameToken(value: "assignto"),
        people: [ Do::PersonReferenceToken(value: "mike") ],
      )
    end

    assert_raise(Do::MissingTokenError) { parse("/assignxxx @mike") }
    assert_raise(Do::MissingTokenError) { parse("/assign") }
    assert_raise(Do::MissingTokenError) { parse("/assign asdf") }
    assert_raise(Do::MissingTokenError) { parse("/assign 1234") }
  end

  test "close card" do
    parse("/close 1234") do |ast|
      ast => Do::CloseCardCommand(
        command: Do::CommandNameToken(value: "close"),
        cards: [ Do::CardReference(value: 1234) ],
      )
    end
    parse("/close 1234 2345") do |ast|
      ast => Do::CloseCardCommand(
        command: Do::CommandNameToken(value: "close"),
        cards: [ Do::CardReference(value: 1234), Do::CardReference(value: 2345) ],
      )
    end
    parse("/close 1234 2345 Duplicate") do |ast|
      ast => Do::CloseCardCommand(
        command: Do::CommandNameToken(value: "close"),
        cards: [ Do::CardReference(value: 1234), Do::CardReference(value: 2345) ],
        reason: Do::StringToken(value: "Duplicate"),
      )
    end
    parse('/close 1234 2345 "Maybe later"') do |ast|
      ast => Do::CloseCardCommand(
        command: Do::CommandNameToken(value: "close"),
        cards: [ Do::CardReference(value: 1234), Do::CardReference(value: 2345) ],
        reason: Do::StringToken(value: "Maybe later"),
      )
    end

    assert_raise(Do::MissingTokenError) { parse("/close") }
    assert_raise(Do::MissingTokenError) { parse("/closexxx 1234") }
  end

  test "tag card" do
    # One or more tags
    parse("/tag #low-pri") do |ast|
      ast => Do::TagCardCommand(
        command: Do::CommandNameToken(value: "tag"),
        tags: [ Do::TagNameToken(value: "low-pri") ],
      )
    end
    parse("/tag #low-pri #small-batch") do |ast|
      ast => Do::TagCardCommand(
        command: Do::CommandNameToken(value: "tag"),
        tags: [ Do::TagNameToken(value: "low-pri"), Do::TagNameToken(value: "small-batch") ],
      )
    end

    # Treat normal strings as tags in this context
    parse("/tag low-pri small-batch") do |ast|
      ast => Do::TagCardCommand(
        command: Do::CommandNameToken(value: "tag"),
        tags: [ Do::StringToken(value: "low-pri"), Do::StringToken(value: "small-batch") ],
      )
    end

    assert_raise(Do::MissingTokenError) { parse("/tag") }
    assert_raise(Do::MissingTokenError) { parse("/tagxxx #low-pri") }
  end

  test "help" do
    parse("/help") { |ast| ast => Do::HelpCommand(command: Do::CommandNameToken(value: "help")) }
    parse("/man") { |ast| ast => Do::HelpCommand(command: Do::CommandNameToken(value: "man")) }
    parse("/?") { |ast| ast => Do::HelpCommand(command: Do::CommandNameToken(value: "?")) }

    assert_raise(Do::MissingTokenError) { parse("/helpxxx") }
  end

  private

    def parse(input, debug: false)
      tokens = Do::Tokenizer.new(input).tokenize
      pp(tokens.to_a) if debug

      ast = Do::Parser.new(tokens).parse
      pp(ast) if debug

      assert_pattern { yield ast }
    end
end
