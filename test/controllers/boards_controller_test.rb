require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_board_path
    assert_response :success
  end

  test "show" do
    get board_path(boards(:writebook))
    assert_response :success
  end

  test "invalidates page title cache when account updates" do
    get board_path(boards(:writebook))
    etag = response.headers["ETag"]

    accounts("37s").update!(name: "Renamed Account")

    get board_path(boards(:writebook)), headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "create" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "Remodel Punch List" } }
    end

    board = Board.last
    assert_redirected_to board_path(board)
    assert_includes board.users, users(:kevin)
    assert_equal "Remodel Punch List", board.name
  end

  test "edit" do
    get edit_board_path(boards(:writebook))
    assert_response :success
  end

  test "update" do
    patch board_path(boards(:writebook)), params: {
      board: {
        name: "Writebook bugs",
        all_access: false,
        auto_postpone_period: 1.day
      },
      user_ids: users(:kevin, :jz).pluck(:id)
    }

    assert_redirected_to edit_board_path(boards(:writebook))
    assert_equal "Writebook bugs", boards(:writebook).reload.name
    assert_equal users(:kevin, :jz).sort, boards(:writebook).users.sort
    assert_equal 1.day, entropies(:writebook_board).auto_postpone_period
    assert_not boards(:writebook).all_access?
  end

  test "update redirects to root when user removes themselves from board" do
    board = boards(:writebook)

    patch board_path(board), params: {
      board: { name: "Updated name", all_access: false },
      user_ids: users(:david, :jz).pluck(:id)
    }

    assert_redirected_to root_path
    assert_not board.reload.users.include?(users(:kevin))
  end

  test "update board with granular permissions, submitting no user ids" do
    assert_not boards(:private).all_access?

    boards(:private).users = [ users(:kevin) ]
    boards(:private).save!

    patch board_path(boards(:private)), params: {
      board: { name: "Renamed" }
    }

    assert_redirected_to edit_board_path(boards(:private))
    assert_equal "Renamed", boards(:private).reload.name
    assert_equal [ users(:kevin) ], boards(:private).users
    assert_not boards(:private).all_access?
  end

  test "update all access" do
    board = Current.set(account: accounts("37s"), session: sessions(:kevin), user: users(:kevin)) do
      Board.create! name: "New board", all_access: false
    end
    assert_equal [ users(:kevin) ], board.users

    patch board_path(board), params: { board: { name: "Bugs", all_access: true } }

    assert_redirected_to edit_board_path(board)
    assert board.reload.all_access?
    assert_equal accounts("37s").users.active.sort, board.users.sort
  end

  test "destroy" do
    board = boards(:writebook)
    delete board_path(board)
    assert_redirected_to root_path
    assert_raises(ActiveRecord::RecordNotFound) { board.reload }
  end

  test "non-admin cannot change all_access on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_all_access = board.all_access

    patch board_path(board), params: { board: { all_access: !original_all_access } }

    assert_response :forbidden
    assert_equal original_all_access, board.reload.all_access
  end

  test "non-admin cannot change individual user accesses on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_users = board.users.sort

    patch board_path(board), params: {
      board: { name: board.name },
      user_ids: [ users(:jz).id ]
    }

    assert_response :forbidden
    assert_equal original_users, board.reload.users.sort
  end

  test "non-admin cannot change board name on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_name = board.name

    patch board_path(board), params: {
      board: { name: "Hacked Board Name" }
    }

    assert_response :forbidden
    assert_equal original_name, board.reload.name
  end

  test "non-admin cannot destroy board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    delete board_path(board)

    assert_response :forbidden
  end

  test "disables select all/none buttons for non-privileged user" do
    logout_and_sign_in_as :jz
    assert_not users(:jz).can_administer_board?(boards(:writebook))

    get edit_board_path(boards(:writebook))

    assert_response :success
    assert_select "button[disabled]", text: "Select all"
    assert_select "button[disabled]", text: "Select none"
  end

  test "enables select all/none buttons for privileged user" do
    assert users(:kevin).can_administer_board?(boards(:writebook))

    get edit_board_path(boards(:writebook))

    assert_response :success
    assert_select "button:not([disabled])", text: "Select all"
    assert_select "button:not([disabled])", text: "Select none"
  end

  test "access toggle disabled state is cached correctly" do
    board = boards(:writebook)
    david = users(:david)

    with_actionview_partial_caching do
      # privileged user
      assert users(:kevin).can_administer_board?(board)

      get edit_board_path(board)

      assert_response :success
      assert_select "input.switch__input[name='user_ids[]'][value='#{david.id}']:not([disabled])"

      # unprivileged user
      logout_and_sign_in_as :jz
      assert_not users(:jz).can_administer_board?(board)

      get edit_board_path(board)

      assert_response :success
      assert_select "input.switch__input[name='user_ids[]'][value='#{david.id}'][disabled]"
    end
  end

  test "index as JSON" do
    get boards_path, as: :json
    assert_response :success
    assert_equal users(:kevin).boards.count, @response.parsed_body.count
  end

  test "index as JSON paginates and preserves recently-accessed order" do
    account = accounts("37s")
    kevin = users(:kevin)
    baseline_accessed_at = 3.days.ago.change(usec: 0)

    kevin.accesses.order(:id).each_with_index do |access, index|
      access.update!(accessed_at: baseline_accessed_at + index.seconds)
    end

    200.times do |index|
      board = Board.create!(
        name: "Recent board #{index}",
        creator: kevin,
        account: account,
        all_access: false
      )
      board.access_for(kevin).update!(accessed_at: baseline_accessed_at + (index + 1).minutes)
    end

    expected_ids = kevin.boards.ordered_by_recently_accessed.pluck(:id)
    actual_ids = []
    next_page = boards_path(format: :json)
    page_count = 0

    while next_page
      get next_page, as: :json
      assert_response :success

      page_count += 1
      actual_ids.concat(@response.parsed_body.map { |board| board["id"] })
      next_page = next_page_from_link_header(@response.headers["Link"])
    end

    assert_equal expected_ids, actual_ids
    assert_operator page_count, :>, 1
  end

  test "show as JSON" do
    get board_path(boards(:writebook)), as: :json
    assert_response :success
    assert_equal boards(:writebook).name, @response.parsed_body["name"]
  end

  test "create as JSON" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "My new board" } }, as: :json
    end

    assert_response :created
    assert_equal board_path(Board.last, format: :json), @response.headers["Location"]
  end

  test "update as JSON" do
    board = boards(:writebook)

    put board_path(board), params: { board: { name: "Updated Name" } }, as: :json

    assert_response :no_content
    assert_equal "Updated Name", board.reload.name
  end

  test "destroy as JSON" do
    board = boards(:writebook)

    assert_difference -> { Board.count }, -1 do
      delete board_path(board), as: :json
    end

    assert_response :no_content
  end

  private
    def next_page_from_link_header(link_header)
      url = link_header&.match(/<([^>]+)>;\s*rel="next"/)&.captures&.first
      URI.parse(url).request_uri if url
    end
end
