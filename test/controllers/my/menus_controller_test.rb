require "test_helper"

class My::MenusControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @user = users(:kevin)
    @account = accounts("37s")
  end

  test "show" do
    get my_menu_path
    assert_response :success
  end

  test "etag invalidates when filters change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @user.filters.create!(
      params_digest: Filter.digest_params({ indexed_by: :all, sorted_by: :newest }),
      fields: { indexed_by: :all, sorted_by: :newest }
    )

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when boards change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @account.boards.create!(name: "New Board", all_access: true, creator: @user)

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when tags change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @account.tags.create!(title: "new-tag")

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when users change" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @user.touch

    get my_menu_path, headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "etag invalidates when account changes" do
    get my_menu_path
    assert_response :success
    etag = response.headers["ETag"]

    @account.update!(name: "Renamed Account")

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

  test "show excludes cancelled accounts" do
    # Create another account for the same identity
    another_account = Account.create!(external_account_id: 9999996, name: "Cancelled Account")
    another_user = @user.identity.users.create!(account: another_account, name: "Kevin", role: "owner")

    # Cancel the other account
    another_account.cancel(initiated_by: another_user)

    get my_menu_path
    assert_response :success

    # The response should include active account but not cancelled one
    assert_select "a[href*='#{@account.slug}']"
    assert_select "a[href*='#{another_account.slug}']", count: 0
  end
end
