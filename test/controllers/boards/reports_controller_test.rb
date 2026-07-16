require "test_helper"

class Boards::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "show returns success for board member" do
    get board_report_path(@board)
    assert_response :success
  end

  test "show is accessible to board members" do
    logout_and_sign_in_as :jz
    get board_report_path(@board)
    assert_response :success
  end

  test "show requires board access" do
    logout_and_sign_in_as :david
    board = boards(:private)

    get board_report_path(board)
    assert_response :not_found
  end

  test "show renders a table row for each board card" do
    get board_report_path(@board)
    assert_select "table.rp-cards-table tbody tr", minimum: @board.cards.count
  end

  test "show includes every card's current tab" do
    get board_report_path(@board)

    assert_select ".reports-page" do |elements|
      report_cards = JSON.parse(elements.first["data-reports-cards-value"])

      assert_equal "In progress", report_cards.find { |card| card["number"] == cards(:text).number }["currentTab"]
      assert_equal "Todos", report_cards.find { |card| card["number"] == cards(:buy_domain).number }["currentTab"]
    end
  end

  test "show page is linked from board header" do
    get board_path(@board)
    assert_select "a[href='#{board_report_path(@board)}']"
  end

  test "show includes card movements with their destination columns" do
    card = cards(:buy_domain)
    @board.events.create!(
      action: "card_triaged",
      creator: users(:kevin),
      eventable: card,
      particulars: { particulars: { column: columns(:writebook_in_progress).name } }
    )

    get board_report_path(@board)

    assert_select ".reports-page" do |elements|
      events = JSON.parse(elements.first["data-reports-events-value"])
      movement = events.find { |event| event["kind"] == "moved" && event["cardNumber"] == card.number }

      assert_equal "In progress", movement["destination"]
      assert movement.key?("workingMinutes")
    end
  end

  test "show represents card closure as a movement to Done" do
    card = cards(:logo)
    card.close(user: users(:kevin))

    get board_report_path(@board)

    assert_select ".reports-page" do |elements|
      events = JSON.parse(elements.first["data-reports-events-value"])
      movement = events.find { |event| event["kind"] == "completed" && event["cardNumber"] == card.number }

      assert_equal "Done", movement["destination"]
    end
  end
end
