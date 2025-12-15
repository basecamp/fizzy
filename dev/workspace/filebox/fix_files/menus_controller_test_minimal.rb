require "test_helper"

class My::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get my_menu_path
    assert_response :success
  end

  test "etag invalidates when account changes" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    accounts("37s").update!(name: "Renamed Account")

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag returns not modified when nothing changes" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified
  end
end