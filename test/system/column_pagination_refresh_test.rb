require "application_system_test_case"

class ColumnPaginationRefreshTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  # A page loads 400ms after its link is observed, and a cold CI server answers slowly.
  PAGE_LOAD_WAIT = 10

  setup do
    sign_in_as(users(:david))
    Current.user = users(:kevin)
    @board = boards(:writebook)
    @column = columns(:writebook_in_progress)
    17.times { |i| add_card_to_column "Paginated #{i}" }
  end

  test "a broadcast refresh keeps every page of a column" do
    visit board_url(@board)
    within("##{dom_id(@column)}") { find("button.cards__expander").click }

    scroll_column_to_bottom
    assert_column_shows_every_card

    wait_for_cable_subscriptions
    add_card_to_column "Added elsewhere"
    @board.broadcast_refresh
    assert_text "Added elsewhere", wait: PAGE_LOAD_WAIT

    scroll_column_to_bottom
    assert_column_shows_every_card
  end

  private
    def add_card_to_column(title)
      @board.cards.create!(title: title, creator: users(:david), status: :published).triage_into(@column)
    end

    def assert_column_shows_every_card
      assert_selector "##{dom_id(@column, :cards)} .card", count: @column.cards.active.count, wait: PAGE_LOAD_WAIT
    end

    def scroll_column_to_bottom
      link = find("##{dom_id(@column, :cards)} .pagination-link", visible: :all)
      page.execute_script("arguments[0].scrollIntoView()", link)
    end

    def wait_for_cable_subscriptions
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
    end
end
