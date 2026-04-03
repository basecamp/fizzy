require "test_helper"

class FiltersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "create via turbo stream" do
    assert_difference "users(:david).filters.count", +1 do
      post filters_path, params: {
        indexed_by: "closed",
        assignment_status: "unassigned",
        tag_ids: [ tags(:mobile).id ],
        assignee_ids: [ users(:jz).id ],
        board_ids: [ boards(:writebook).id ] }, as: :turbo_stream
    end
    assert_response :success

    filter = Filter.last
    assert_predicate filter.indexed_by, :closed?
    assert_predicate filter.assignment_status, :unassigned?
    assert_equal [ tags(:mobile) ], filter.tags
    assert_equal [ users(:jz) ], filter.assignees
    assert_equal [ boards(:writebook) ], filter.boards
  end

  test "destroy via turbo stream" do
    filter = filters(:jz_assignments)

    assert_difference "users(:david).filters.count", -1 do
      delete filter_path(filter), as: :turbo_stream
    end
    assert_response :success
  end

  test "index as json" do
    extra_filter = users(:david).filters.create!(creator_ids: [ users(:david).id ])

    get filters_path, as: :json

    assert_response :success
    assert_equal [ extra_filter.id, filters(:jz_assignments).id ], @response.parsed_body.pluck("id")
    assert_equal extra_filter.summary, @response.parsed_body.first["summary"]
  end

  test "index rejects html" do
    get filters_path

    assert_response :not_acceptable
  end

  test "show as json" do
    filter = filters(:jz_assignments)

    get filter_path(filter), as: :json

    assert_response :success
    assert_equal filter.id, @response.parsed_body["id"]
    assert_equal filter.summary, @response.parsed_body["summary"]
    assert_equal filter.as_params.as_json, @response.parsed_body["params"]
    assert_equal cards_url(filter_id: filter.id), @response.parsed_body["cards_url"]
  end

  test "show rejects html" do
    get filter_path(filters(:jz_assignments))

    assert_response :not_acceptable
  end

  test "show only exposes current user's filters" do
    other_filter = users(:kevin).filters.create!(creator_ids: [ users(:kevin).id ])

    get filter_path(other_filter), as: :json

    assert_response :not_found
  end

  test "create as json" do
    assert_difference "users(:david).filters.count", +1 do
      post filters_path, params: {
        indexed_by: "closed",
        tag_ids: [ tags(:mobile).id ],
        assignee_ids: [ users(:jz).id ],
        board_ids: [ boards(:writebook).id ],
        terms: [ "login" ]
      }, as: :json
    end

    assert_response :created
    filter = Filter.find(@response.parsed_body["id"])
    assert_equal filter.summary, @response.parsed_body["summary"]
    assert_equal filter.as_params.as_json, @response.parsed_body["params"]
    assert_equal filter_url(filter, format: :json), @response.parsed_body["url"]
    assert_equal cards_url(filter_id: filter.id), @response.parsed_body["cards_url"]
  end

  test "create as json reuses equivalent saved filter" do
    filter = users(:david).filters.create!(tag_ids: [ tags(:mobile).id ], assignee_ids: [ users(:jz).id ])

    assert_no_difference "users(:david).filters.count" do
      post filters_path, params: {
        assignee_ids: [ users(:jz).id ],
        tag_ids: [ tags(:mobile).id ],
        sorted_by: "latest"
      }, as: :json
    end

    assert_response :ok
    assert_equal filter.id, @response.parsed_body["id"]
  end

  test "create as json rejects invalid values" do
    assert_no_difference "users(:david).filters.count" do
      post filters_path, params: { indexed_by: "bogus", creation: "someday" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "is invalid" ], @response.parsed_body.dig("errors", "indexed_by")
    assert_equal [ "is invalid" ], @response.parsed_body.dig("errors", "creation")
  end

  test "create as json rejects inaccessible ids" do
    assert_no_difference "users(:david).filters.count" do
      post filters_path, params: {
        board_ids: [ boards(:private).id ],
        tag_ids: [ tags(:mobile).id ],
        creator_ids: [ users(:mike).id ]
      }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "contains unknown or inaccessible ids" ], @response.parsed_body.dig("errors", "board_ids")
    assert_equal [ "contains unknown or inaccessible ids" ], @response.parsed_body.dig("errors", "creator_ids")
  end

  test "create as json rejects malformed array fields" do
    assert_no_difference "users(:david).filters.count" do
      post filters_path, params: { board_ids: boards(:writebook).id, terms: "login" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "must be an array" ], @response.parsed_body.dig("errors", "board_ids")
    assert_equal [ "must be an array" ], @response.parsed_body.dig("errors", "terms")
  end

  test "create as json rejects card ids" do
    assert_no_difference "users(:david).filters.count" do
      post filters_path, params: { card_ids: [ cards(:logo).id ] }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal [ "contains unsupported keys: card_ids" ], @response.parsed_body.dig("errors", "base")
  end

  test "destroy as json" do
    filter = filters(:jz_assignments)

    assert_difference "users(:david).filters.count", -1 do
      delete filter_path(filter), as: :json
    end

    assert_response :no_content
  end
end
