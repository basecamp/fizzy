require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @signup_params = {
      full_name: "Brian Wilson",
      email_address: "brian@example.com",
      company_name: "Beach Boys",
      password: SecureRandom.hex(16)
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
    assert_select "h2", "Create your account"
    assert_select "input[name='signup[full_name]']"
    assert_select "input[name='signup[email_address]']"
    assert_select "input[name='signup[company_name]']"
    assert_select "input[name='signup[password]']"
  end

  test "should create signup and redirect to tenant root on success" do
    Account.any_instance.expects(:setup_basic_template).once

    assert_difference -> { ApplicationRecord.tenants.count }, 1 do
      post saas.signup_url, params: { signup: @signup_params }, headers: http_basic_auth_headers
    end

    assert_response :redirect

    new_tenant = (ApplicationRecord.tenants - @starting_tenants).first
    ApplicationRecord.with_tenant(new_tenant) do
      account = Account.sole
      assert account, "Account should have been created"
      assert_equal @signup_params[:company_name], account.name

      user = User.find_by(email_address: @signup_params[:email_address])
      assert user, "User should have been created"
      assert_equal @signup_params[:full_name], user.name
      assert_equal @signup_params[:email_address], user.email_address

      assert_redirected_to root_url(script_name: account.slug)
    end
  end

  test "should render new with errors when signup fails validation" do
    invalid_params = @signup_params.merge(password: "")

    assert_no_difference -> { ApplicationRecord.tenants.count } do
      post saas.signup_url, params: { signup: invalid_params }, headers: http_basic_auth_headers
    end

    assert_response :unprocessable_entity
    assert_select ".alert--error"
    assert_select ".alert--error li", /Password can't be blank/
  end

  test "should render new with errors when signup processing fails" do
    Queenbee::Remote::Account.stubs(:create!).raises(RuntimeError, "Invalid account data")

    assert_no_difference -> { ApplicationRecord.tenants.count } do
      post saas.signup_url, params: { signup: @signup_params }, headers: http_basic_auth_headers
    end

    assert_response :unprocessable_entity
    assert_select ".alert--error"
    assert_select ".alert--error li", /An error occurred during signup/
  end

  private
    def http_basic_auth_headers
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials("testname", "testpassword")
      { "HTTP_AUTHORIZATION" => credentials }
    end
end
