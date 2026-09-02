require "application_system_test_case"

class Boards::RoadmapsTest < ApplicationSystemTestCase
  include ActionView::RecordIdentifier

  test "a board member visits the roadmap and sees phases, statuses, and step progress" do
    board = boards(:writebook)

    Current.set(session: sessions(:david)) do
      epic = board.cards.create!(title: "Ship the new nav", creator: users(:david), status: "published")
      epic.toggle_tag_with "phase:p1"
      epic.toggle_tag_with "type:epic"
      epic.toggle_tag_with "domain:design"
      epic.steps.create!(content: "Design", completed: true)
      epic.steps.create!(content: "Build", completed: true)
      epic.steps.create!(content: "Launch", completed: false)
      epic.close

      later_story = board.cards.create!(title: "Polish the empty states", creator: users(:david), status: "published")
      later_story.toggle_tag_with "phase:p2"

      board.cards.create!(title: "Investigate flaky test", creator: users(:david), status: "published")
    end

    sign_in_as(users(:david))
    visit board_roadmap_url(board)

    assert_equal [ "P1", "P2", "Unphased" ], all("section.roadmap__phase h2").map(&:text)

    within "#roadmap_phase_p1" do
      assert_text "Ship the new nav"
      assert_selector ".roadmap__card .btn", text: /design/i
      assert_selector ".roadmap__card", text: /shipped/i
      assert_text "2/3"
    end

    within "#roadmap_phase_p2" do
      assert_text "Polish the empty states"
    end

    within "#roadmap_phase_unphased" do
      assert_text "Investigate flaky test"
    end

    assert_selector ".roadmap__summary", text: "1/1"
  end

  test "a board with no cards shows an empty roadmap" do
    board = Board.create!(name: "Freshly minted", creator: users(:david), account: accounts(:"37s"))

    sign_in_as(users(:david))
    visit board_roadmap_url(board)

    assert_text "No cards on this board yet."
  end

  test "a broadcast refresh shows a card closed elsewhere as shipped" do
    board = boards(:writebook)

    card = Current.set(session: sessions(:david)) do
      board.cards.create!(title: "Ship the thing", creator: users(:david), status: "published").tap do |card|
        card.toggle_tag_with "phase:p1"
      end
    end

    sign_in_as(users(:david))
    visit board_roadmap_url(board)

    card_row = "##{dom_id(card, :roadmap)}"
    assert_selector card_row, text: "Ship the thing"
    assert_no_selector card_row, text: /shipped/i

    close_card_elsewhere(card)

    assert_selector card_row, text: /shipped/i, wait: 5
  end

  private
    def close_card_elsewhere(card)
      wait_for_cable_subscriptions
      Current.set(session: sessions(:david)) { card.close }
      perform_enqueued_jobs only: Turbo::Streams::BroadcastStreamJob
    end

    # A broadcast sent before the page's subscriptions are confirmed is lost.
    def wait_for_cable_subscriptions
      assert_selector "turbo-cable-stream-source[connected]", visible: :all
      assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
    end
end
