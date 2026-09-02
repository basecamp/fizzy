require "test_helper"

class Board::RoadmapTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @board = boards(:writebook)
  end

  test "an epic tagged phase:p1 lands in the P1 group as an epic" do
    card = publish_card title: "Ship the redesign"
    card.toggle_tag_with "phase:p1"
    card.toggle_tag_with "type:epic"

    group = phase_group("p1")

    assert_equal "P1", group.title
    assert_includes group.epics.map(&:card), card
  end

  test "bare p2 and epic tags are recognized the same as their namespaced form" do
    card = publish_card title: "Bare tag epic"
    card.toggle_tag_with "p2"
    card.toggle_tag_with "epic"

    group = phase_group("p2")

    assert_equal "P2", group.title
    assert_includes group.epics.map(&:card), card
  end

  test "phases are ordered numerically, non-numbered phases sort after, and Unphased always sorts last" do
    p10_card = publish_card(title: "Far future")
    p10_card.toggle_tag_with "phase:p10"

    p0_card = publish_card(title: "Right now")
    p0_card.toggle_tag_with "phase:p0"

    beta_card = publish_card(title: "Named phase")
    beta_card.toggle_tag_with "phase:beta"

    unphased_card = publish_card(title: "No phase tag at all")

    labels = roadmap.phase_groups.map(&:label)

    assert_equal %w[ p0 p10 beta unphased ], labels
    assert_includes phase_group("unphased").cards.map(&:card), unphased_card
  end

  test "closed card is reported as shipped" do
    card = publish_card(title: "Done deal")
    card.close

    assert_equal :shipped, status_of(card)
  end

  test "postponed card is reported as not_now" do
    card = publish_card(title: "Later maybe")
    card.postpone

    assert_equal :not_now, status_of(card)
  end

  test "triaged open card is reported as in_flight" do
    card = publish_card(title: "Working on it", column: columns(:writebook_in_progress))

    assert_equal :in_flight, status_of(card)
  end

  test "untriaged published card is reported as planned" do
    card = publish_card(title: "Needs a column")

    assert_equal :planned, status_of(card)
  end

  test "stalled card is reported as stalled" do
    card = publish_card(title: "Gone quiet", column: columns(:writebook_in_progress))
    card.create_activity_spike!

    travel_to 3.months.from_now

    assert_equal :stalled, status_of(card)
  end

  test "step progress reports completed over total steps" do
    card = publish_card(title: "Has steps")
    card.steps.create!(content: "one", completed: true)
    card.steps.create!(content: "two", completed: true)
    card.steps.create!(content: "three", completed: false)

    roadmap_card = find_roadmap_card(card)

    assert_equal 2, roadmap_card.steps_completed
    assert_equal 3, roadmap_card.steps_total
  end

  test "a card with no steps reports 0 of 0" do
    card = publish_card(title: "No steps here")

    roadmap_card = find_roadmap_card(card)

    assert_equal 0, roadmap_card.steps_completed
    assert_equal 0, roadmap_card.steps_total
  end

  test "board rollups tally shipped epics, in-flight cards, and deferred cards" do
    board = Board.create!(name: "Rollups", creator: users(:david), account: accounts(:"37s"))
    column = board.columns.create!(name: "In progress")

    shipped_epic = board.cards.create!(title: "Shipped epic", creator: users(:david), status: "published")
    shipped_epic.toggle_tag_with "type:epic"
    shipped_epic.close

    board.cards.create!(title: "In flight", creator: users(:david), status: "published", column: column)

    not_now_card = board.cards.create!(title: "Not now", creator: users(:david), status: "published")
    not_now_card.postpone

    board.cards.create!(title: "Planned", creator: users(:david), status: "published")

    summary = Board::Roadmap.new(board).summary

    assert_equal 1, summary.total_epics
    assert_equal 1, summary.epics_shipped
    assert_equal 1, summary.in_flight
    assert_equal 1, summary.deferred
    assert_equal 1, summary.planned
  end

  test "a card tagged with several phases is grouped under the lowest one, deterministically" do
    card = publish_card(title: "Multi-phase card")
    card.toggle_tag_with "phase:p3"
    card.toggle_tag_with "phase:p1"
    card.toggle_tag_with "phase:p2"

    p1_group = phase_group("p1")

    assert_includes p1_group.cards.map(&:card) + p1_group.epics.map(&:card), card
    assert_nil phase_group("p2")
    assert_nil phase_group("p3")
  end

  test "a card tagged domain:billing reports that domain" do
    card = publish_card(title: "Billing card")
    card.toggle_tag_with "domain:billing"

    assert_equal [ "billing" ], find_roadmap_card(card).domains
  end

  test "a card tagged with two domains reports both" do
    card = publish_card(title: "Multi-domain card")
    card.toggle_tag_with "domain:billing"
    card.toggle_tag_with "domain:payments"

    assert_equal %w[ billing payments ], find_roadmap_card(card).domains.sort
  end

  test "a bare tag without the domain: namespace is not recognized as a domain" do
    card = publish_card(title: "Bare domain-looking tag")
    card.toggle_tag_with "billing"

    assert_empty find_roadmap_card(card).domains
  end

  test "a type:story card lands among group.cards, not group.epics" do
    card = publish_card(title: "Namespaced story")
    card.toggle_tag_with "phase:p5"
    card.toggle_tag_with "type:story"

    group = phase_group("p5")

    assert_includes group.cards.map(&:card), card
    assert_not_includes group.epics.map(&:card), card
  end

  test "a bare story tag lands among group.cards, not group.epics" do
    card = publish_card(title: "Bare story")
    card.toggle_tag_with "phase:p5"
    card.toggle_tag_with "story"

    group = phase_group("p5")

    assert_includes group.cards.map(&:card), card
    assert_not_includes group.epics.map(&:card), card
  end

  test "a card with no type tag defaults to a story" do
    card = publish_card(title: "Untyped card")

    assert_equal :story, find_roadmap_card(card).type
  end

  test "a card tagged as both epic and story resolves to epic" do
    card = publish_card(title: "Both typed")
    card.toggle_tag_with "type:epic"
    card.toggle_tag_with "type:story"

    assert_equal :epic, find_roadmap_card(card).type
  end

  test "a phase group partitions its epics and stories separately" do
    epic = publish_card(title: "Phase epic")
    epic.toggle_tag_with "phase:p6"
    epic.toggle_tag_with "type:epic"

    story = publish_card(title: "Phase story")
    story.toggle_tag_with "phase:p6"

    group = phase_group("p6")

    assert_equal [ epic ], group.epics.map(&:card)
    assert_equal [ story ], group.cards.map(&:card)
  end

  test "a phase's rollup tallies shipped, stalled, in_flight, and planned cards independently" do
    shipped = publish_card(title: "Shipped in phase")
    shipped.toggle_tag_with "phase:p4"
    shipped.close

    stalled = publish_card(title: "Stalled in phase", column: columns(:writebook_in_progress))
    stalled.toggle_tag_with "phase:p4"
    stalled.create_activity_spike!

    travel_to 3.months.from_now

    in_flight = publish_card(title: "In flight in phase", column: columns(:writebook_in_progress))
    in_flight.toggle_tag_with "phase:p4"

    planned = publish_card(title: "Planned in phase")
    planned.toggle_tag_with "phase:p4"

    group = phase_group("p4")

    assert_equal 1, group.rollup.shipped
    assert_equal 1, group.rollup.stalled
    assert_equal 1, group.rollup.in_flight
    assert_equal 1, group.rollup.planned
    assert_equal 4, group.rollup.total
  end

  test "ordered_cards lists epics before stories, each ordered shipped, in_flight, stalled, planned, not_now" do
    shipped_story = publish_card(title: "Shipped story")
    shipped_story.toggle_tag_with "phase:p7"
    shipped_story.close

    not_now_story = publish_card(title: "Not now story")
    not_now_story.toggle_tag_with "phase:p7"
    not_now_story.postpone

    planned_story = publish_card(title: "Planned story")
    planned_story.toggle_tag_with "phase:p7"

    stalled_epic = publish_card(title: "Stalled epic", column: columns(:writebook_in_progress))
    stalled_epic.toggle_tag_with "phase:p7"
    stalled_epic.toggle_tag_with "type:epic"
    stalled_epic.create_activity_spike!

    travel_to 3.months.from_now

    in_flight_epic = publish_card(title: "In flight epic", column: columns(:writebook_in_progress))
    in_flight_epic.toggle_tag_with "phase:p7"
    in_flight_epic.toggle_tag_with "type:epic"

    group = phase_group("p7")

    assert_equal [ in_flight_epic, stalled_epic ], group.ordered_cards.first(2).map(&:card)
    assert_equal [ shipped_story, planned_story, not_now_story ], group.ordered_cards.last(3).map(&:card)
  end

  test "an empty board reports no phase groups at all and an all-zero summary" do
    empty_board = Board.create!(name: "Empty", creator: users(:david), account: accounts(:"37s"))
    empty_roadmap = Board::Roadmap.new(empty_board)

    assert_equal [], empty_roadmap.phase_groups

    summary = empty_roadmap.summary

    assert_equal 0, summary.total_epics
    assert_equal 0, summary.epics_shipped
    assert_equal 0, summary.in_flight
    assert_equal 0, summary.deferred
    assert_equal 0, summary.planned
  end

  test "closed wins over postponed when a card is somehow forced into both states" do
    card = publish_card(title: "Both states at once")
    card.create_closure!(user: users(:david))
    card.create_not_now!(user: users(:david))

    assert_equal :shipped, status_of(card)
  end

  test "a published card on a different board never appears in this board's roadmap" do
    other_board_card = boards(:private).cards.create!(title: "Wrong board card", creator: users(:kevin), status: "published")

    assert_nil find_roadmap_card(other_board_card)
  end

  private
    def publish_card(title:, column: nil)
      @board.cards.create!(title: title, creator: users(:david), status: "published", column: column)
    end

    def roadmap
      Board::Roadmap.new(@board)
    end

    def phase_group(label)
      roadmap.phase_groups.find { |group| group.label == label }
    end

    def find_roadmap_card(card)
      roadmap.phase_groups.flat_map(&:cards).concat(roadmap.phase_groups.flat_map(&:epics)).find { |rc| rc.card == card }
    end

    def status_of(card)
      find_roadmap_card(card).status
    end
end
