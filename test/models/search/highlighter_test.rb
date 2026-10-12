require "test_helper"

class Search::HighlighterTest < ActiveSupport::TestCase
  test "CJK matches preserve original text and group adjacent characters" do
    assert_equal "这是#{mark('中文')}测试", highlight("这是中文测试", "中文")
    assert_equal "#{mark('日本語')}の説明", highlight("日本語の説明", "日本語")
    assert_equal "#{mark('한국어')} 설명", highlight("한국어 설명", "한국어")
  end

  test "CJK phrases do not highlight reversed or separated characters" do
    assert_equal "文中 中间文 #{mark('中文')}", highlight("文中 中间文 中文", "中文")
  end

  test "mixed adjacent scripts share the same boundaries as the index" do
    assert_equal "#{mark('Fizzy中文')}测试", highlight("Fizzy中文测试", "Fizzy中文")
  end

  test "stemming highlights the original word" do
    assert_equal "Card to #{mark('delete')}", highlight("Card to delete", "deleting")
    assert_equal "#{mark('Running')} tests", highlight("Running tests", "run")
  end

  test "Latin accents and decomposed queries highlight the original word" do
    assert_equal "#{mark('Hälsa')} och friskvård", highlight("Hälsa och friskvård", "ha\u0308lsa")
    assert_equal "#{mark("ha\u0308lsa")}", highlight("ha\u0308lsa", "hälsa")
  end

  test "decomposed Japanese accents stay attached to their character" do
    assert_equal mark("カ\u3099"), highlight("カ\u3099", "ガ")
  end

  test "overlapping query terms produce one pair of markers" do
    assert_equal mark("中文测试"), highlight("中文测试", "中文 中文测试")
    assert_equal mark("testing"), highlight("testing", "test testing")
  end

  test "query terms never match generated markup" do
    assert_equal "#{mark('test')} #{mark('class')}", highlight("test class", "test class")
  end

  test "quoted phrases retain original spacing and punctuation" do
    assert_equal "Say #{mark('hello, world')}!", highlight("Say hello, world!", '"hello world"')
  end

  test "long CJK snippets use character boundaries and mark both cuts" do
    text = "前" * 40 + "中文" + "后" * 40
    assert_equal "...前前前前前#{mark('中文')}后后后...",
      Search::Highlighter.new("中文").snippet(text, max_words: 10)
  end

  test "long text without matches adds no markers" do
    text = "Some text " * 30
    assert_equal text, Search::Highlighter.new("中文").snippet(text, max_words: 10)
  end

  private
    def highlight(text, query)
      Search::Highlighter.new(query).highlight(text)
    end

    def mark(text)
      "#{ActiveSearch::Highlighting::STORE_OPEN_MARKER}#{text}#{ActiveSearch::Highlighting::STORE_CLOSE_MARKER}"
    end
end
