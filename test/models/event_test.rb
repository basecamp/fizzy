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

  test "api_particulars returns empty strings for missing nested board change values" do
    event = boards(:writebook).events.create!(
      action: "card_board_changed",
      creator: users(:david),
      eventable: cards(:logo),
      account: accounts("37s"),
      particulars: {}
    )

    assert_equal({ "old_board" => "", "new_board" => "" }, event.api_particulars)
  end

  test "api_particulars returns empty strings for missing nested title and column values" do
    title_event = boards(:writebook).events.create!(
      action: "card_title_changed",
      creator: users(:david),
      eventable: cards(:logo),
      account: accounts("37s"),
      particulars: {}
    )

    triage_event = boards(:writebook).events.create!(
      action: "card_triaged",
      creator: users(:david),
      eventable: cards(:logo),
      account: accounts("37s"),
      particulars: {}
    )

    assert_equal({ "old_title" => "", "new_title" => "" }, title_event.api_particulars)
    assert_equal({ "column" => "" }, triage_event.api_particulars)
  end
end
