require "test_helper"

class Filter::SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "deduplicate multiple results" do
    card = @board.cards.create!(title: "Duplicate results test", description: "Have you had any haggis today?", creator: @user, status: "published")
    card.comments.create(body: "I hate haggis.", creator: @user)
    card.comments.create(body: "I love haggis.", creator: @user)

    filter = @user.filters.new(terms: [ "haggis" ], indexed_by: "all", sorted_by: "latest")

    assert_equal [ card ], filter.cards.to_a
  end

  test "multiple terms all match" do
    matching_card = @board.cards.create!(title: "haggis neeps tatties", creator: @user, status: "published")
    @board.cards.create!(title: "haggis only", creator: @user, status: "published")
    @board.cards.create!(title: "neeps only", creator: @user, status: "published")

    filter = @user.filters.new(terms: [ "haggis", "neeps" ], indexed_by: "all", sorted_by: "latest")

    assert_equal [ matching_card ], filter.cards.to_a
  end
end
