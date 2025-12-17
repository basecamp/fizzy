require "test_helper"

class Signup::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup = Signup.new(email_address: "newuser@example.com", full_name: "New User")

    @signup.create_identity || raise("Failed to create identity")

    sign_in_as @signup.identity
  end

  test "new" do
    untenanted do
      get new_signup_completion_path
    end

    assert_response :success
  end

  test "create" do
    untenanted do
      post signup_completion_path, params: {
        signup: {
          full_name: @signup.full_name
        }
      }
    end

    assert_response :redirect, "Valid params should redirect"
  end

  test "create with blank name" do
    untenanted do
      post signup_completion_path, params: {
        signup: {
          full_name: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".txt-negative" do
      assert_select "li", text: "Full name can't be blank"
    end
  end
end
