require "test_helper"

class Boards::AccessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index returns active account users with access status" do
    board = boards(:writebook)

    get board_accesses_path(board), as: :json
    assert_response :success

    body = @response.parsed_body
    assert_equal board.id, body["board_id"]
    assert body["all_access"]

    user_ids = body["users"].map { |u| u["id"] }
    accounts("37s").users.active.each do |user|
      assert_includes user_ids, user.id
    end
  end

  test "index includes has_access and involvement for users with access" do
    board = boards(:writebook)
    board.access_for(users(:kevin)).update!(involvement: :watching)

    get board_accesses_path(board), as: :json

    kevin_entry = @response.parsed_body["users"].find { |u| u["id"] == users(:kevin).id }
    assert kevin_entry["has_access"]
    assert_equal "watching", kevin_entry["involvement"]
  end

  test "index shows has_access false and nil involvement for users without access" do
    board = boards(:private)

    get board_accesses_path(board), as: :json
    assert_response :success

    david_entry = @response.parsed_body["users"].find { |u| u["id"] == users(:david).id }
    assert_not david_entry["has_access"]
    assert_nil david_entry["involvement"]
  end

  test "index includes standard user fields" do
    get board_accesses_path(boards(:writebook)), as: :json

    user_entry = @response.parsed_body["users"].first
    assert user_entry.key?("id")
    assert user_entry.key?("name")
    assert user_entry.key?("role")
    assert user_entry.key?("email_address")
    assert user_entry.key?("avatar_url")
  end

  test "index requires board access" do
    logout_and_sign_in_as :david
    board = boards(:private)

    get board_accesses_path(board), as: :json
    assert_response :not_found
  end

  test "index is accessible to non-admin board members" do
    logout_and_sign_in_as :jz
    board = boards(:writebook)

    get board_accesses_path(board), as: :json
    assert_response :success
  end

  test "index paginates account users" do
    account = accounts("37s")
    board = boards(:private)

    200.times do |index|
      identity = Identity.create!(email_address: "board-membership-#{index}@example.com")
      account.users.create!(identity: identity, name: "Board Membership User #{index}", role: :member)
    end

    expected_ids = account.users.active.alphabetically.pluck(:id)
    actual_ids = []
    next_page = board_accesses_path(board, format: :json)
    page_count = 0

    while next_page
      get next_page, as: :json
      assert_response :success

      page_count += 1
      actual_ids.concat(@response.parsed_body["users"].map { |user| user["id"] })
      next_page = next_page_from_link_header(@response.headers["Link"])
    end

    assert_equal expected_ids, actual_ids
    assert_operator page_count, :>, 1
  end

  private
    def next_page_from_link_header(link_header)
      url = link_header&.match(/<([^>]+)>;\s*rel="next"/)&.captures&.first
      URI.parse(url).request_uri if url
    end
end
