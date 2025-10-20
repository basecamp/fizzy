require "test_helper"

class IdentitiesControllerTest < ActionDispatch::IntegrationTest
  include Fizzy::Saas::Engine.routes.url_helpers

  setup do
    @token = InternalApiClient.token
  end

  test "link" do
    new_email = "newuser@example.com"
    tenant = ApplicationRecord.current_tenant
    body = { email_address: new_email, to: tenant }.to_json

    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { Membership.count }, 1 do
        untenanted do
          post link_identity_url(script_name: nil), params: body, headers: authenticated_headers(body)
        end
      end
    end

    assert_response :ok
    assert Identity.find_by(email_address: new_email).memberships.exists?(tenant: tenant)
  end

  test "unlink" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant
    body = { email_address: identity.email_address, from: tenant }.to_json

    assert_difference -> { Membership.count }, -1 do
      untenanted do
        post unlink_identity_url(script_name: nil), params: body, headers: authenticated_headers(body)
      end
    end

    assert_response :ok
  end

  test "change_email_address" do
    identity = identities(:kevin)
    tenant = ApplicationRecord.current_tenant
    new_email = "newemail@example.com"
    body = { from: identity.email_address, to: new_email, tenant: tenant }.to_json

    untenanted do
      post change_identity_email_address_url(script_name: nil), params: body, headers: authenticated_headers(body)
    end

    assert_response :ok
    assert Identity.find_by(email_address: new_email).memberships.exists?(tenant: tenant)
  end

  test "send_magic_link" do
    identity = identities(:kevin)
    body = { email_address: identity.email_address }.to_json

    assert_difference -> { MagicLink.count }, 1 do
      untenanted do
        post send_magic_link_url(script_name: nil), params: body, headers: authenticated_headers(body)
      end
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal MagicLink::CODE_LENGTH, json["code"].length

    body = { email_address: "nonexistent@example.com" }.to_json
    untenanted do
      post send_magic_link_url(script_name: nil), params: body, headers: authenticated_headers(body)
    end

    assert_response :ok
    json = JSON.parse(response.body)
    assert_nil json["code"]
  end

  test "authentication" do
    body = { email_address: "test@example.com" }.to_json

    untenanted do
      post send_magic_link_url(script_name: nil), params: body, headers: { "Content-Type" => "application/json" }
    end
    assert_response :unauthorized

    untenanted do
      post send_magic_link_url(script_name: nil), params: body, headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@token}",
        "X-Internal-Signature" => "invalid"
      }
    end
    assert_response :unauthorized
  end

  private
    def authenticated_headers(body)
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@token}",
        "X-Internal-Signature" => InternalApiClient.signature_for(body)
      }
    end
end
