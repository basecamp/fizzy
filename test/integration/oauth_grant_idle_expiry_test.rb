require "test_helper"

# A grant lapses once its refresh token goes unused for the idle window, as
# bc3's refresh tokens do: each refresh restarts the clock, and a lapsed grant
# takes a fresh authorization, with consent.
class OauthGrantIdleExpiryTest < ActionDispatch::IntegrationTest
  setup do
    @client = oauth_clients(:mcp_client)
    freeze_time
    @grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :read)
  end

  test "a grant refreshes up to the end of the idle window" do
    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT
    refresh @grant.refresh_token

    assert_response :success
  end

  test "a grant idle past the window lapses" do
    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.second
    refresh @grant.refresh_token

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "each refresh restarts the idle clock" do
    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT - 1.day
    refresh @grant.refresh_token
    assert_response :success

    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT - 1.day
    refresh response.parsed_body["refresh_token"]

    assert_response :success
  end

  test "a lapsed grant leaves Connected Apps" do
    sign_in_as :david

    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT + 1.second
    get my_connected_apps_path

    assert_response :success
    assert_no_match @client.name, response.body
  end

  test "the sweep removes lapsed grants and keeps live ones" do
    live = identities(:david).access_tokens.create!(oauth_client: @client, permission: :read)
    personal = identities(:david).access_tokens.create!(permission: :read, description: "PAT")

    later_by Identity::AccessToken::REFRESH_IDLE_LIMIT - 1.day
    live.refresh

    later_by 1.day + 1.second
    Identity::AccessToken.cleanup

    assert_not Identity::AccessToken.exists?(@grant.id)
    assert Identity::AccessToken.exists?(live.id)
    assert Identity::AccessToken.exists?(personal.id)
  end

  private
    # Elapsed time in the app's zone, as the model counts it: travel would add
    # calendar days in the local zone, an hour off across a DST change.
    def later_by(duration)
      travel_to Time.current + duration
    end

    def refresh(refresh_token)
      untenanted do
        post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id }
      end
    end
end
