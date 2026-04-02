require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "blank creator and board filters return the current relation unchanged" do
    relation = Event.where(action: "card_published")

    assert_equal relation.to_sql, relation.for_creators(nil).to_sql
    assert_equal relation.to_sql, relation.for_creators([]).to_sql
    assert_equal relation.to_sql, relation.for_boards(nil).to_sql
    assert_equal relation.to_sql, relation.for_boards([]).to_sql
  end

  test "blank creator and board filters remain chainable" do
    relation = Event.where(action: "card_published")

    assert_nothing_raised do
      relation.for_creators([]).for_boards([]).load
    end
  end
end
