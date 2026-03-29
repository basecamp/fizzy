require "test_helper"
require "shellwords"

class Boards::AgentBootstrapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_board_agent_bootstrap_path(boards(:writebook))
    assert_response :success
    assert_in_body "Generate setup command"
  end

  test "create as JSON" do
    board = boards(:writebook)

    assert_difference -> { board.agent_bootstraps.count }, +1 do
      post board_agent_bootstraps_path(board), as: :json
    end

    assert_response :created
    body = @response.parsed_body
    assert body["bootstrap_url"].present?
    assert body["skill_url"].present?
    assert body["setup_command"].present?
    assert_equal "fizzy-cli", body["skill_name"]
    assert_match %r{/agent_bootstrap/[^/]+/claim\z}, body["bootstrap_url"]
    assert_match %r{/agent_bootstrap/[^/]+/skill\z}, body["skill_url"]
    assert_not_includes body["bootstrap_url"], "/#{board.account.slug}/"
    assert_not_includes body["skill_url"], "/#{board.account.slug}/"
    assert_includes body["skill_block"], body["skill_url"]
    assert_includes body["skill_block"], body["setup_command"]
    assert_equal "watching", body["involvement"]
    assert_equal board.id, body.dig("board", "id")
  end

  test "setup command shell-escapes board-derived arguments" do
    board = boards(:writebook)
    board.update!(name: %(Danger "$(touch /tmp/nope)" `rm -rf /`))

    post board_agent_bootstraps_path(board), as: :json

    assert_response :created
    command = @response.parsed_body.fetch("setup_command")
    argv = Shellwords.split(command)

    assert_equal "fizzy", argv[0]
    assert_equal "auth", argv[1]
    assert_equal "bootstrap", argv[2]
    assert_equal "--email", argv[4]
    assert_match(/\Aagent\+[A-Za-z0-9]{8}@example\.com\z/, argv[5])
    assert_equal "#{board.name} Agent", argv.last
  end

  test "new requires account admin" do
    logout_and_sign_in_as :jz

    get new_board_agent_bootstrap_path(boards(:writebook))

    assert_response :forbidden
  end

  test "show" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )

    get board_agent_bootstrap_path(bootstrap.board, bootstrap)
    assert_response :success
    assert_in_body bootstrap.token
    assert_in_body "Copy skill URL"
    assert_in_body "Copy agent prompt"
  end

  test "show requires account admin" do
    bootstrap = boards(:writebook).agent_bootstraps.create!(
      account: accounts("37s"),
      creator: users(:kevin),
      expires_at: 30.minutes.from_now
    )

    logout_and_sign_in_as :jz
    get board_agent_bootstrap_path(bootstrap.board, bootstrap)

    assert_response :forbidden
  end

  test "board page includes agent setup link for account admins" do
    get board_path(boards(:writebook))
    assert_response :success
    assert_select "a[href='#{new_board_agent_bootstrap_path(boards(:writebook))}']"
  end

  test "board creator who is not an account admin cannot see bootstrap link" do
    logout_and_sign_in_as :jz
    board = Current.set(account: accounts("37s"), user: users(:jz)) do
      Board.create!(name: "Creator board", creator: users(:jz), all_access: false)
    end

    get board_path(board)

    assert_response :success
    assert_select "a[href='#{new_board_agent_bootstrap_path(board)}']", count: 0
  end

  test "board creator who is not an account admin cannot create bootstrap" do
    logout_and_sign_in_as :jz
    board = Current.set(account: accounts("37s"), user: users(:jz)) do
      Board.create!(name: "Creator board", creator: users(:jz), all_access: false)
    end

    assert users(:jz).can_administer_board?(board)

    assert_no_difference -> { board.agent_bootstraps.count } do
      post board_agent_bootstraps_path(board), as: :json
    end

    assert_response :forbidden
  end

  test "non-admin cannot create bootstrap for board they do not administer" do
    logout_and_sign_in_as :jz

    assert_no_difference -> { boards(:writebook).agent_bootstraps.count } do
      post board_agent_bootstraps_path(boards(:writebook)), as: :json
    end

    assert_response :forbidden
  end
end
