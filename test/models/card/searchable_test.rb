require "test_helper"

class Card::SearchableTest < ActiveSupport::TestCase
  setup do
    Card.all.each(&:reindex)
    Comment.all.each(&:reindex)
  end

  test "searching by title" do
    assert_includes Card.mentioning("layout is broken"), cards(:layout)
  end

  test "searching by comment" do
    assert_includes Card.mentioning("overflowing"), cards(:layout)
  end

  test "sanitizing search query" do
    assert_includes Card.mentioning("broken \""), cards(:layout)
  end

  test "a search with no valid terms returns empty results" do
    assert_empty Card.mentioning("\"")
  end
end
