require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup_params = {
      full_name: "Brian Wilson",
      email_address: "brian@example.com",
      company_name: "Beach Boys"
    }
    @starting_tenants = ApplicationRecord.tenants

    # Clear script_name for untenanted signup tests
    integration_session.default_url_options[:script_name] = nil
  end

  test "should require http basic authentication" do
    get saas.new_signup_url

    assert_response :unauthorized
  end

  test "should get new" do
    get saas.new_signup_url, headers: http_basic_auth_headers

    assert_response :success
    assert_select "h1", "Sign up"
    assert_select "input[name='signup[email_address]']"
  end

  test "should create signup and redirect to magic link page" do
    assert_no_difference -> { ApplicationRecord.tenants.count } do
      post saas.signup_url, params: { signup: { email_address: @signup_params[:email_address] } }, headers: http_basic_auth_headers
    end

    assert_redirected_to session_magic_link_path
  end

  test "should render new with errors when signup fails validation" do
    invalid_params = { email_address: "" }

    assert_no_difference -> { ApplicationRecord.tenants.count } do
      post saas.signup_url, params: { signup: invalid_params }, headers: http_basic_auth_headers
    end

    assert_response :unprocessable_entity
    assert_select ".txt-negative"
  end

  private
    def http_basic_auth_headers
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials("testname", "testpassword")
      { "HTTP_AUTHORIZATION" => credentials }
    end
end
