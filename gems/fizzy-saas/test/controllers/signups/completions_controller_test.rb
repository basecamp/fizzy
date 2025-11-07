require "test_helper"

class Signup::CompletionsControllerTest < ActionDispatch::IntegrationTest
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
        account_name: @signup.account_name })
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
      }
    end

    assert_redirected_to landing_path(script_name: "/#{@signup.tenant}"), "Successful completion should redirect to root in new tenant"

    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          membership_id: @membership_id,
          full_name: "",
          account_name: ""
        }
      }
    end

    assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
  end
end
