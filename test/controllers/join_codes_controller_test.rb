require "test_helper"

class JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = ApplicationRecord.current_tenant
    @join_code = account_join_codes(:sole)
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
        assert_difference -> { Membership.count }, 1 do
          post join_path(tenant: @tenant, code: @join_code.code), params: { email_address: "new_user@example.com" }
        end
      end

      assert_equal @join_code.code, Membership.last.join_code

      assert_redirected_to session_magic_link_path
      assert_equal landing_url(script_name: "/#{@tenant}"), session[:return_to_after_authenticating]
    end
  end

  test "create for existing identity" do
    identity = identities(:jz)

    untenanted do
      assert_no_difference -> { Identity.count } do
        assert_no_difference -> { Membership.count } do
          post join_path(tenant: @tenant, code: @join_code.code), params: { email_address: identity.email_address }
        end
      end

      assert_redirected_to session_magic_link_path
    end
  end
end
