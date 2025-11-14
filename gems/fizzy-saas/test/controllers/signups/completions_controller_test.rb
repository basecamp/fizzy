require "test_helper"

class Signup::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup = Signup.new(email_address: "newuser@example.com", full_name: "New User")

    @signup.create_identity || raise("Failed to create identity")

    sign_in_as @signup.identity
  end

  test "new" do
    untenanted do
      get saas.new_signup_completion_path
    end

    assert_response :success
  end

  test "create" do
    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          full_name: @signup.full_name,
        }
      }
    end

    assert_response :redirect, "Valid params should redirect"
  end

  test "create with invalid params" do
    untenanted do
      post saas.signup_completion_path, params: {
        signup: {
          full_name: "",
        }
      }
    end

    assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
  end
end
