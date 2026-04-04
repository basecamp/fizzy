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

  test "stem CJK characters" do
    result = Search::Stemmer.stem("测试中文")

    assert_equal "测 试 中 文", result
  end

  test "stem Japanese characters" do
    result = Search::Stemmer.stem("日本語テスト")

    assert_equal "日 本 語 テ ス ト", result
  end

  test "stem Korean characters" do
    result = Search::Stemmer.stem("한국어테스트")

    assert_equal "한 국 어 테 스 트", result
  end

  test "stem mixed CJK and English" do
    result = Search::Stemmer.stem("hello世界test")

    assert_equal "hello 世 界 test", result
  end

  test "stem mixed with English stemming" do
    result = Search::Stemmer.stem("running 测试 jumping")

    assert_equal "run 测 试 jump", result
  end

  test "stem_query preserves quoted phrases" do
    result = Search::Stemmer.stem_query('"hello world" running')

    assert_equal '"hello world" run', result
  end

  test "stem_query stems words inside quotes" do
    result = Search::Stemmer.stem_query('"running tests"')

    assert_equal '"run test"', result
  end

  test "stem_query handles CJK with quotes" do
    result = Search::Stemmer.stem_query('"测试" running')

    assert_equal '"测 试" run', result
  end

  test "stem_query without quotes behaves like stem" do
    result = Search::Stemmer.stem_query("running jumping")

    assert_equal "run jump", result
  end

  test "stem_query wraps unquoted CJK tokens as phrase" do
    result = Search::Stemmer.stem_query("中文 running")

    assert_equal '"中 文" run', result
  end
end
