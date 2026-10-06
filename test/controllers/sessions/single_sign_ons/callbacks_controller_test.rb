require "test_helper"

class Sessions::SingleSignOns::CallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_single_sign_on
    stub_single_sign_on_provider
  end

  teardown do
    disable_single_sign_on
  end

  test "sign in" do
    sign_in_with_single_sign_on sub: "jz-subject"

    assert_redirected_to landing_url(script_name: nil)
    assert_equal identities(:jz), current_session.identity
    assert current_session.recently_authenticated_by_single_sign_on?
  end

  test "sign in keeps the groups on the session" do
    sign_in_with_single_sign_on sub: "jz-subject", groups: [ "/engineering/fizzy", "/sales" ]

    assert_equal [ "/engineering/fizzy", "/sales" ], current_session.single_sign_on_groups
  end

  test "sign in returns to the address given at the start" do
    boards_url = "http://www.example.com/#{accounts("37s").external_account_id}/boards"
    sign_in_with_single_sign_on sub: "jz-subject", return_to: boards_url

    assert_redirected_to boards_url
  end

  test "sign in ignores a return address on another host" do
    sign_in_with_single_sign_on sub: "jz-subject", return_to: "https://other.example.com/boards"

    assert_redirected_to landing_url(script_name: nil)
  end

  test "sign in replaces the current session" do
    disable_single_sign_on
    sign_in_as :jz
    previous_session = current_session
    enable_single_sign_on

    sign_in_with_single_sign_on sub: "jz-subject"

    assert_not Session.exists?(previous_session.id)
    assert_not_equal previous_session, current_session
    assert current_session.recently_authenticated_by_single_sign_on?
  end

  test "first sign-in on a new server goes to signup completion" do
    Account.stubs(:none?).returns(true)

    sign_in_with_single_sign_on sub: "newcomer-subject", email: "newcomer@example.com"

    assert_redirected_to new_signup_completion_url(script_name: nil)
    assert_equal "newcomer@example.com", current_session.identity.email_address
  end

  test "first sign-in of a member of the admin group opens the accounts" do
    enable_single_sign_on admin_group: "/fizzy/admin"

    sign_in_with_single_sign_on sub: "newcomer-subject", email: "newcomer@example.com", groups: [ "/sales" ]
    assert_response :unauthorized

    sign_in_with_single_sign_on sub: "newcomer-subject", email: "newcomer@example.com", groups: [ "/fizzy/admin" ]

    assert_redirected_to landing_url(script_name: nil)
    assert_equal Account.active.count, current_session.identity.users.admin.count
  end

  test "sign in without access to an account" do
    with_multi_tenant_mode(false) do
      assert_no_difference -> { Identity.count } do
        sign_in_with_single_sign_on sub: "newcomer-subject", email: "newcomer@example.com"
      end
    end

    assert_response :unauthorized
    assert_select "p", text: /do not have access to a Fizzy account/
    assert_nil parsed_cookies.signed[:session_token]
  end

  test "sign in with an email address that is not confirmed" do
    sign_in_with_single_sign_on sub: "kevin-subject", email_verified: false

    assert_response :unauthorized
    assert_select "p", text: /not confirmed/
  end

  test "state that does not match" do
    untenanted do
      post session_single_sign_on_path
      get session_single_sign_on_callback_path, params: { code: "fizzy-code", state: "other-state" }
    end

    assert_response :unauthorized
    assert_select "p", text: /expired or is not valid/
    assert_not_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT
  end

  test "state works once" do
    untenanted do
      post session_single_sign_on_path
      authorization = single_sign_on_authorization_parameters

      complete_single_sign_on authorization, sub: "jz-subject"
      assert_response :redirect

      complete_single_sign_on authorization, sub: "jz-subject"
      assert_response :unauthorized
    end
  end

  test "several sign-in requests at the same time" do
    untenanted do
      post session_single_sign_on_path
      first_authorization = single_sign_on_authorization_parameters
      post session_single_sign_on_path

      complete_single_sign_on first_authorization, sub: "jz-subject"
    end

    assert_response :redirect
    assert_equal identities(:jz), current_session.identity
  end

  test "error from the provider" do
    untenanted do
      post session_single_sign_on_path
      authorization = single_sign_on_authorization_parameters
      get session_single_sign_on_callback_path, params: { error: "access_denied", state: authorization["state"] }
    end

    assert_response :unauthorized
    assert_select "p", text: /did not work/
  end

  test "expired sign-in request" do
    untenanted do
      post session_single_sign_on_path
      authorization = single_sign_on_authorization_parameters

      travel SingleSignOn::AuthorizationRequest::EXPIRATION_TIME + 1.minute
      complete_single_sign_on authorization, sub: "jz-subject"
    end

    assert_response :unauthorized
    assert_nil parsed_cookies.signed[:session_token]
  end

  test "ID token signed with another key" do
    sign_in_with_single_sign_on sub: "jz-subject", key: OpenSSL::PKey::RSA.generate(2048)

    assert_response :unauthorized
    assert_nil parsed_cookies.signed[:session_token]
  end

  test "not found when single sign-on is not configured" do
    disable_single_sign_on

    untenanted do
      get session_single_sign_on_callback_path, params: { code: "fizzy-code", state: "state" }
    end

    assert_response :not_found
  end
end
