require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_user_path(params: { join_code: "bad" })
    assert_response :forbidden

    get new_user_path(params: { join_code: account_join_codes(:sole).code })
    assert_response :ok
  end

  test "create" do
    assert_difference -> { User.count }, +1 do
      assert_difference -> { Identity.count }, +1 do
        post users_path(params: { join_code: account_join_codes(:sole).code }),
          params: { user: { name: "Dash", email_address: "dash@example.com" } }
        assert_redirected_to session_magic_link_path(script_name: nil)
      end
    end
  end

  test "show" do
    sign_in_as :kevin

    get user_path(users(:david))
    assert_in_body users(:david).name
  end

  test "update oneself" do
    sign_in_as :kevin

    get edit_user_path(users(:kevin))
    assert_response :ok

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }
    assert_redirected_to user_path(users(:kevin))
    assert_equal "New Kevin", users(:kevin).reload.name
  end

  test "update other as admin" do
    sign_in_as :kevin

    get edit_user_path(users(:david))
    assert_response :ok

    put user_path(users(:david)), params: { user: { name: "New David" } }
    assert_redirected_to user_path(users(:david))
    assert_equal "New David", users(:david).reload.name
  end

  test "destroy" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david))
    end

    assert_redirected_to users_path
    assert_nil User.active.find_by(id: users(:david).id)
  end

  test "non-admins cannot perform actions" do
    sign_in_as :jz

    put user_path(users(:david)), params: { user: { role: "admin" } }
    assert_response :forbidden

    delete user_path(users(:david))
    assert_response :forbidden
  end
end
