require "test_helper"

class Account::ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new for a member of the admin group with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/fizzy/admin" ])

    with_single_sign_on admin_group: "/fizzy/admin" do
      untenanted do
        get new_account_import_path
      end
    end

    assert_response :success
  end

  test "show outside the account group with single sign-on" do
    account = accounts("37s")
    import = Account::Import.create!(account: account, identity: identities(:kevin))
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/sales" ])

    with_single_sign_on do
      account.update!(single_sign_on_group: "/engineering")

      get account_import_path(import, script_name: account.slug)
    end

    assert_response :forbidden
    assert_select "h1", text: "Account access denied"
  end

  test "create outside the admin group with single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: Time.current, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/sales" ])

    with_single_sign_on admin_group: "/fizzy/admin" do
      untenanted do
        assert_no_difference -> { Account.count } do
          post account_imports_path, params: { file: fixture_file_upload("moon.jpg", "image/jpeg") }
        end

        assert_redirected_to session_menu_url
      end
    end
  end
end
