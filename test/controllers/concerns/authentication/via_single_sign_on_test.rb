require "test_helper"

class Authentication::ViaSingleSignOnTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    enable_single_sign_on
    stub_single_sign_on_provider
  end

  teardown do
    disable_single_sign_on
  end

  test "a session without single sign-on goes to single sign-on" do
    get cards_path

    assert_redirected_to new_session_single_sign_on_url(script_name: nil)
    assert_equal cards_url, session[:return_to_after_authenticating]
  end

  test "a session without single sign-on goes to single sign-on outside an account too" do
    untenanted do
      get session_menu_path
    end

    assert_redirected_to new_session_single_sign_on_url(script_name: nil)
  end

  test "a recent single sign-on session opens the account" do
    current_session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER)

    get cards_path

    assert_response :success
  end

  test "a single sign-on session older than the reauthentication period goes to single sign-on" do
    current_session.update!(single_sign_on_authenticated_at: 13.hours.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER)

    get cards_path

    assert_redirected_to new_session_single_sign_on_url(script_name: nil)
  end

  test "single sign-on returns to the page" do
    get cards_path

    sign_in_with_single_sign_on sub: "kevin-subject"
    assert_redirected_to cards_url

    get cards_path
    assert_response :success
  end

  test "a Turbo frame request returns to the page that holds the frame" do
    get cards_path, headers: { "Turbo-Frame" => "cards", "Referer" => boards_url }

    assert_redirected_to new_session_single_sign_on_url(script_name: nil)
    assert_equal boards_url, session[:return_to_after_authenticating]
  end

  test "a form submission returns to the page that holds the form" do
    post boards_path, params: { board: { name: "Plans" } }, headers: { "Referer" => boards_url }

    assert_redirected_to new_session_single_sign_on_url(script_name: nil)
    assert_equal boards_url, session[:return_to_after_authenticating]
  end

  test "JSON requests get forbidden" do
    get cards_path, as: :json

    assert_response :forbidden
    assert_equal "single_sign_on_required", response.parsed_body["error"]
    assert_equal "Sign in with SSO.", response.parsed_body["message"]
  end

  test "access tokens get forbidden" do
    reset!

    get cards_path(script_name: accounts("37s").slug), as: :json,
      headers: { "Authorization" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }

    assert_response :forbidden
    assert_equal "single_sign_on_required", response.parsed_body["error"]
  end

  test "a session in the account group opens the account" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    current_session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/engineering/fizzy" ])

    get cards_path

    assert_response :success
  end

  test "a session outside the account group gets the group page" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    current_session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/sales" ])

    get cards_path

    assert_response :forbidden
    assert_select "h1", text: "Account access denied"
    assert_select "strong", text: "/engineering/fizzy"
    assert_select "form[action='/session/single_sign_on'] input[name=return_to][value='#{cards_url}']"
  end

  test "a JSON request outside the account group gets forbidden" do
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")
    current_session.update!(single_sign_on_authenticated_at: 1.hour.ago, single_sign_on_issuer: SINGLE_SIGN_ON_ISSUER, single_sign_on_groups: [ "/sales" ])

    get cards_path, as: :json

    assert_response :forbidden
    assert_equal "single_sign_on_group_required", response.parsed_body["error"]
    assert_equal "This account requires the SSO group /engineering/fizzy.", response.parsed_body["message"]
  end

  test "access works as before when single sign-on is not configured" do
    disable_single_sign_on
    accounts("37s").update!(single_sign_on_group: "/engineering/fizzy")

    get cards_path

    assert_response :success
  end

  test "public boards stay open" do
    boards(:writebook).publish

    get published_board_path(boards(:writebook))

    assert_response :success
  end
end
