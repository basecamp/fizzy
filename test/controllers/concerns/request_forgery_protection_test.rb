require "test_helper"

class RequestForgeryProtectionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin

    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  test "fails if Sec-Fetch-Site is cross-site" do
    assert_no_difference -> { Board.count } do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "Sec-Fetch-Site" => "cross-site" }
    end

    assert_response :unprocessable_entity
  end

  test "succeeds with same-origin Sec-Fetch-Site" do
    assert_difference -> { Board.count }, +1 do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "Sec-Fetch-Site" => "same-origin" }
    end

    assert_response :redirect
  end

  test "succeeds with same-site Sec-Fetch-Site" do
    assert_difference -> { Board.count }, +1 do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "Sec-Fetch-Site" => "same-site" }
    end

    assert_response :redirect
  end

  test "fails with none Sec-Fetch-Site" do
    assert_no_difference -> { Board.count } do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "Sec-Fetch-Site" => "none" }
    end

    assert_response :unprocessable_entity
  end

  test "fails when Sec-Fetch-Site header is missing" do
    assert_no_difference -> { Board.count } do
      post boards_path, params: { board: { name: "Test Board" } }
    end

    assert_response :unprocessable_entity
  end

  test "GET requests succeed regardless of Sec-Fetch-Site header" do
    get board_path(boards(:writebook)), headers: { "Sec-Fetch-Site" => "cross-site" }

    assert_response :success
  end

  test "appends Sec-Fetch-Site to Vary header on GET requests" do
    get board_path(boards(:writebook))

    assert_response :success
    assert_includes response.headers["Vary"], "Sec-Fetch-Site"
  end

  test "appends Sec-Fetch-Site to Vary header on POST requests" do
    post boards_path,
      params: { board: { name: "Test Board" } },
      headers: { "Sec-Fetch-Site" => "same-origin" }

    assert_response :redirect
    assert_includes response.headers["Vary"], "Sec-Fetch-Site"
  end

  test "JSON request succeeds with missing Sec-Fetch-Site" do
    assert_difference -> { Board.count }, +1 do
      post boards_path,
        params: { board: { name: "Test Board" } },
        as: :json
    end

    assert_response :created
  end

  test "JSON request fails with cross-site Sec-Fetch-Site" do
    assert_no_difference -> { Board.count } do
      post boards_path,
        params: { board: { name: "Test Board" } },
        headers: { "Sec-Fetch-Site" => "cross-site" },
        as: :json
    end

    assert_response :unprocessable_entity
  end

  private
    def csrf_token
      @csrf_token ||= begin
        get new_board_path
        response.body[/name="authenticity_token" value="([^"]+)"/, 1]
      end
    end
end
