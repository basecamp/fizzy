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
end
