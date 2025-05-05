require "test_helper"

class DoTokenizerTest < ActiveSupport::TestCase
  test "tokenize string" do
    parse("hello") { |tok| tok => [Do::StringToken(value: "hello"), Do::EOFToken] }

    # Special characters are allowed.
    parse("👋áçöñ☕") { |tok| tok => [Do::StringToken(value: "👋áçöñ☕"), Do::EOFToken] }

    # Note that numbers aren't treated differently by the tokenizer, though the parser will check if
    # an initial string token is a number.
    parse("1234") { |tok| tok => [Do::StringToken(value: "1234"), Do::EOFToken] }

    # Multiple words are allowed
    parse("hello world") do |tokens|
      tokens => [
        Do::StringToken(value: "hello"),
        Do::WhitespaceToken,
        Do::StringToken(value: "world"),
        Do::EOFToken,
      ]
    end

    # Quoted strings are treated as a single string
    parse('load "activity feed" performance') do |tokens|
      tokens => [
        Do::StringToken(value: "load"),
        Do::WhitespaceToken,
        Do::StringToken(value: "activity feed"),
        Do::WhitespaceToken,
        Do::StringToken(value: "performance"),
        Do::EOFToken,
      ]
    end
    parse("load 'activity feed' performance") do |tokens|
      tokens => [
        Do::StringToken(value: "load"),
        Do::WhitespaceToken,
        Do::StringToken(value: "activity feed"),
        Do::WhitespaceToken,
        Do::StringToken(value: "performance"),
        Do::EOFToken,
      ]
    end
  end

  test "tokenize person reference" do
    parse("@mike") { |tok| tok => [Do::PersonReferenceToken(value: "mike"), Do::EOFToken] }

    parse("abc @mike xyz") do |tok|
      tok => [
        Do::StringToken(value: "abc"),
        Do::WhitespaceToken,
        Do::PersonReferenceToken(value: "mike"),
        Do::WhitespaceToken,
        Do::StringToken(value: "xyz"),
        Do::EOFToken,
      ]
    end

    # An @ sign by itself is an empty reference, not a bare string.
    parse("@") { |tok| tok => [Do::PersonReferenceToken(value: ""), Do::EOFToken] }
  end

  test "tag reference" do
    parse("#low-pri") { |tok| tok => [ Do::TagNameToken(value: "low-pri"), Do::EOFToken ] }
    parse("#👋áçöñ☕") { |tok| tok => [ Do::TagNameToken(value: "👋áçöñ☕"), Do::EOFToken ] }
    parse("#") { |tok| tok => [ Do::TagNameToken(value: ""), Do::EOFToken ] }
  end

  private

    def parse(input, debug: false)
      tokens = Do::Tokenizer.new(input).tokenize.to_a
      pp(tokens) if debug

      assert_pattern { yield tokens }
    end
end
