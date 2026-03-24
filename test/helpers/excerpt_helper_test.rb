require "test_helper"

class ExcerptHelperTest < ActionView::TestCase
  test "quote" do
    assert_excerpt("> Hello world", ">    Hello world")
  end

  test "ul" do
    assert_excerpt("• Hello world", "-    Hello world")
    assert_excerpt("• Hello world", "  -    Hello world")
  end

  test "ol" do
    assert_excerpt("99. Hello world", "99.    Hello world")
    assert_excerpt("99. Hello world", "  99.    Hello world")
  end

  test "large spaces" do
    assert_excerpt("Hello world", "   Hello    world     ")
  end

  test "long text" do
    assert_excerpt("A"*197 + "...", "A"*1000)
    assert_excerpt("A"*97 + "...", "A"*1000, length: 100)
  end

  private
    def assert_excerpt(expected, content, ...)
      assert_equal expected, format_excerpt(ActionText::Content.new(content), ...), "Excerpt of Action Text Content does not match"
      assert_equal expected, format_excerpt(content, ...), "Excerpt of String does not match"
    end
end
