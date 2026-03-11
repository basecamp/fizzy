require "test_helper"

class My::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create new token" do
    get my_access_tokens_path
    assert_response :success

    get new_my_access_token_path
    assert_response :success

    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
      follow_redirect!
      assert_in_body identities(:kevin).access_tokens.last.token
    end
  end

  test "create new token via JSON with session" do
    assert_difference -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "write" } }, as: :json
    end
    assert_response :created
    body = @response.parsed_body
    assert body["id"].present?
    assert body["token"].present?
    assert_equal "Fizzy CLI", body["description"]
    assert_equal "write", body["permission"]
    assert body["created_at"].present?
  end

  test "create new token via JSON with bearer token" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    assert_difference -> { identities(:david).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "read" } }, env: bearer_token, as: :json
    end
    assert_response :created
    body = @response.parsed_body
    assert body["token"].present?
    assert_equal "Fizzy CLI", body["description"]
    assert_equal "read", body["permission"]
  end

  test "cannot create new token via JSON with read-only bearer token" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }

    assert_no_difference -> { identities(:jason).access_tokens.count } do
      post my_access_tokens_path, params: { access_token: { description: "Fizzy CLI", permission: "read" } }, env: bearer_token, as: :json
    end
    assert_response :unauthorized
  end

  test "index as JSON" do
    get my_access_tokens_path, as: :json
    assert_response :success

    body = @response.parsed_body
    assert_kind_of Array, body
  end

  test "index as JSON with bearer token and no account scope" do
    sign_out
    bearer_token = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:davids_api_token).token}" }

    untenanted do
      get my_access_tokens_path, as: :json, env: bearer_token
    end

    assert_response :success
    assert_kind_of Array, @response.parsed_body
  end

  test "destroy as JSON" do
    token = identities(:kevin).access_tokens.create!(description: "To delete", permission: "read")

    assert_difference -> { identities(:kevin).access_tokens.count }, -1 do
      delete my_access_token_path(token), as: :json
    end

    assert_response :no_content
  end

  test "accessing new token after reveal window redirects to index" do
    assert_changes -> { identities(:kevin).access_tokens.count }, +1 do
      post my_access_tokens_path, params: { access_token: { description: "GitHub", permission: "read" } }
      travel_to 15.seconds.from_now
      follow_redirect!
      assert_equal "Token is no longer visible", flash[:alert]
    end
  end
end
