require "test_helper"

class Signups::CompletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_identity_as :kevin
  end

  test "new" do
    get saas.new_signup_completion_path

    assert_response :success
  end

  test "create" do
    post saas.signup_completion_path, params: {
      signup: {
        full_name: "Kevin Systrom",
        company_name: "37signals"
      }
    }

    assert_redirected_to root_path, "Successful completion should redirect to root"
    assert cookies[:session_token].present?, "Successful completion should create a session"
    assert_equal "Kevin Systrom", users(:kevin).reload.name, "User name should be updated"
    assert_equal "37signals", Account.sole.reload.name, "Account name should be updated"

    post saas.signup_completion_path, params: {
      signup: {
        full_name: "",
        company_name: ""
      }
    }

    assert_response :unprocessable_entity, "Invalid params should return unprocessable entity"
  end
end
