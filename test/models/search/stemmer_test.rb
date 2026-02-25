require "test_helper"

class Search::StemmerTest < ActiveSupport::TestCase
  test "stem single word" do
    result = Search::Stemmer.stem("running")

    assert_equal "run", result
  end

  test "stem multiple words" do
    result = Search::Stemmer.stem("test, running      JUMPING & walking")

    assert_equal "test run jump walk", result
  end

  test "stem hyphenated words" do
    result = Search::Stemmer.stem("BC3-IOS-1D8B")

    assert_equal "bc3 io 1d8b", result
  end

  test "stem words separated by repeated punctuation" do
    result = Search::Stemmer.stem("foo---bar")

    assert_equal "foo bar", result
  end
end
