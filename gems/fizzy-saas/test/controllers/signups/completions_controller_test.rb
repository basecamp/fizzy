require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup = Signup.new(email_address: "newuser@example.com", full_name: "New User")

    @signup.create_identity || raise("Failed to create identity")

    sign_in_as @signup.identity

    @signup.create_membership || raise("Failed to create membership")
  end

  test "new" do
    untenanted do
      get saas.new_signup_completion_path(signup: {
        membership_id: @signup.membership_id,
        full_name: @signup.full_name,
        account_name: @signup.account_name }), headers: http_basic_auth_headers
    end

    assert_response :success
  end

  test "create" do
    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          membership_id: @signup.membership_id,
          full_name: @signup.full_name,
          account_name: @signup.account_name
        }
      }, headers: http_basic_auth_headers
    end

    assert_redirected_to root_url(script_name: "/#{@signup.tenant}"), "Successful completion should redirect to root in new tenant"

    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          membership_id: @membership_id,
          full_name: "",
          account_name: ""
        }
      }, headers: http_basic_auth_headers
    end

    assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
  end

  private
    def http_basic_auth_headers
      { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("testname", "testpassword") }
    end
end
