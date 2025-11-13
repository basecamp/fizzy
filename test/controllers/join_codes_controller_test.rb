require "test_helper"

class JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = accounts("37s").external_account_id
    @join_code = account_join_codes(:"37s")
  end

  test "new" do
    untenanted do
      get join_path(tenant: @tenant, code: @join_code.code)
    end

    assert_response :success
    assert_in_body "37signals"
  end

  test "new with an invalid code" do
    untenanted do
      get join_path(tenant: @tenant, code: "INVALID-CODE")
    end

    assert_response :not_found
  end

  test "new with an inactive code" do
    @join_code.update!(usage_count: @join_code.usage_limit)

    untenanted do
      get join_path(tenant: @tenant, code: @join_code.code)
    end

    assert_response :not_found
  end

  test "create" do
    untenanted do
      assert_difference -> { Identity.count }, 1 do
        assert_difference -> { User.count }, 1 do
          post join_path(tenant: @tenant, code: @join_code.code), params: { email_address: "new_user@example.com" }
        end
      end

      assert_redirected_to session_magic_link_path
      account = accounts("37s")
      assert_equal new_users_join_url(script_name: account.slug), session[:return_to_after_authenticating]
    end
  end

  test "create for existing identity" do
    identity = identities(:jz)

    untenanted do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { User.count } do
          post join_path(tenant: @tenant, code: @join_code.code), params: { email_address: identity.email_address }
        end
      end

      account = accounts("37s")
      assert_redirected_to landing_url(script_name: account.slug)
    end
  end
end
