require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index returns flat array of events with required envelope fields" do
    get activities_path, as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
    assert body.any?

    event = body.first
    assert_includes event.keys, "id"
    assert_includes event.keys, "action"
    assert_includes event.keys, "created_at"
    assert_includes event.keys, "description"
    assert_includes event.keys, "particulars"
    assert_includes event.keys, "url"
    assert_includes event.keys, "eventable_type"
    assert_includes event.keys, "eventable"
    assert_includes event.keys, "board"
    assert_includes event.keys, "creator"
  end

  test "index returns events in reverse-chronological order" do
    get activities_path, as: :json
    assert_response :success

    times = @response.parsed_body.map { |e| Time.parse(e["created_at"]) }
    assert_equal times, times.sort.reverse
  end

  test "index includes card eventable" do
    event = events(:logo_published)
    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "Card", item["eventable_type"]
    assert_equal cards(:logo).title, item["eventable"]["title"]
    assert_equal "card_published", item["action"]
    assert item["url"].end_with?("/cards/#{cards(:logo).number}")
  end

  test "index includes comment eventable" do
    event = events(:layout_commented)
    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "Comment", item["eventable_type"]
    assert_equal card_url(event.eventable.card, anchor: ActionView::RecordIdentifier.dom_id(event.eventable)), item["url"]
    assert item["eventable"]["body"].present?
  end

  test "index includes board and creator at top level" do
    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.first
    assert item["board"]["id"].present?
    assert item["board"]["name"].present?
    assert item["creator"]["id"].present?
    assert item["creator"]["name"].present?
  end

  test "index normalizes particulars for card_assigned" do
    event = events(:logo_assignment_jz)
    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "card_assigned", item["action"]
    assert_equal [ users(:jz).id ], item["particulars"]["assignee_ids"]
  end

  test "index normalizes particulars for card_unassigned" do
    card = cards(:logo)
    event = card.board.events.create!(
      action: "card_unassigned",
      creator: users(:david),
      eventable: card,
      account: accounts("37s"),
      particulars: { assignee_ids: [ users(:jz).id ] }
    )

    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal [ users(:jz).id ], item["particulars"]["assignee_ids"]
  end

  test "index returns empty particulars for actions with no payload" do
    event = events(:logo_published)
    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal({}, item["particulars"])
  end

  test "index normalizes particulars for card_board_changed" do
    card = cards(:logo)
    event = card.board.events.create!(
      action: "card_board_changed",
      creator: users(:david),
      eventable: card,
      account: accounts("37s"),
      particulars: { particulars: { old_board: "Backlog", new_board: "Mobile" } }
    )

    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "Backlog", item["particulars"]["old_board"]
    assert_equal "Mobile", item["particulars"]["new_board"]
  end

  test "index normalizes particulars for card_title_changed" do
    card = cards(:logo)
    event = card.board.events.create!(
      action: "card_title_changed",
      creator: users(:david),
      eventable: card,
      account: accounts("37s"),
      particulars: { particulars: { old_title: "Old title", new_title: "New title" } }
    )

    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "Old title", item["particulars"]["old_title"]
    assert_equal "New title", item["particulars"]["new_title"]
  end

  test "index normalizes particulars for card_triaged" do
    card = cards(:logo)
    event = card.board.events.create!(
      action: "card_triaged",
      creator: users(:david),
      eventable: card,
      account: accounts("37s"),
      particulars: { particulars: { column: "In Progress" } }
    )

    get activities_path, as: :json
    assert_response :success

    item = @response.parsed_body.find { |e| e["id"] == event.id }
    assert_not_nil item
    assert_equal "In Progress", item["particulars"]["column"]
  end

  test "index filters by creator_ids" do
    get activities_path(creator_ids: [ users(:kevin).id ]), as: :json
    assert_response :success

    body = @response.parsed_body
    assert body.any?
    assert body.all? { |e| e["creator"]["id"] == users(:kevin).id }
  end

  test "index filters by multiple creator_ids with OR semantics" do
    get activities_path(creator_ids: [ users(:david).id, users(:kevin).id ]), as: :json
    assert_response :success

    body = @response.parsed_body
    creator_ids = body.map { |e| e["creator"]["id"] }.uniq.sort
    assert_includes creator_ids, users(:david).id
    assert_includes creator_ids, users(:kevin).id
  end

  test "index filters by board_ids" do
    get activities_path(board_ids: [ boards(:writebook).id ]), as: :json
    assert_response :success

    body = @response.parsed_body
    assert body.any?
    assert body.all? { |e| e["board"]["id"] == boards(:writebook).id }
  end

  test "index ANDs creator_ids and board_ids filters" do
    get activities_path(creator_ids: [ users(:david).id ], board_ids: [ boards(:writebook).id ]), as: :json
    assert_response :success

    body = @response.parsed_body
    assert body.any?
    assert body.all? { |e| e["creator"]["id"] == users(:david).id }
    assert body.all? { |e| e["board"]["id"] == boards(:writebook).id }
  end

  test "index ignores empty creator_ids and board_ids filters" do
    get activities_path(creator_ids: [], board_ids: []), as: :json
    assert_response :success

    assert_predicate @response.parsed_body, :any?
  end

  test "index only returns events from accessible boards" do
    get activities_path, as: :json
    assert_response :success

    accessible_board_ids = users(:kevin).boards.pluck(:id)
    @response.parsed_body.each do |item|
      assert_includes accessible_board_ids, item["board"]["id"]
    end
  end

  test "index paginates and returns Link header when more results exist" do
    board = boards(:writebook)
    30.times do |i|
      board.events.create!(
        action: "card_published",
        creator: users(:kevin),
        eventable: cards(:logo),
        account: accounts("37s")
      )
    end

    get activities_path, as: :json
    assert_response :success

    link_header = @response.headers["Link"]
    assert link_header.present?, "Expected a Link header for paginated results"
    assert_match(/rel="next"/, link_header)
  end

  test "index follows pagination to retrieve all events" do
    board = boards(:writebook)
    30.times do
      board.events.create!(
        action: "card_published",
        creator: users(:kevin),
        eventable: cards(:logo),
        account: accounts("37s")
      )
    end

    all_ids = []
    next_path = activities_path(format: :json)

    while next_path
      get next_path
      assert_response :success
      all_ids.concat(@response.parsed_body.map { |e| e["id"] })
      next_path = next_page_from_link_header(@response.headers["Link"])
    end

    total = Event.where(board: users(:kevin).boards).where(action: ActivitiesController::ACTIONS).count
    assert_equal total, all_ids.uniq.count
  end

  private
    def next_page_from_link_header(link_header)
      url = link_header&.match(/<([^>]+)>;\s*rel="next"/)&.captures&.first
      URI.parse(url).request_uri if url
    end
end
