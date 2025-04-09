require "test_helper"

class Bubble::SearchableTest < ActiveSupport::TestCase
  setup do
    Bubble.all.each(&:reindex)
    Comment.all.each(&:reindex)
  end

  test "searching by title" do
    assert_includes Bubble.mentioning("layout is broken"), bubbles(:layout)
  end

  test "searching by comment" do
    assert_includes Bubble.mentioning("overflowing"), bubbles(:layout)
  end

  test "sanitizing search query" do
    assert_includes Bubble.mentioning("broken \""), bubbles(:layout)
  end

  test "a search with no valid terms returns empty results" do
    assert_empty Bubble.mentioning("\"")
  end
end
