require "test_helper"

# Grants for the hosted MCP server (hosted plan, phase B): audienced to it by
# RFC 8707's resource parameter, bound to the one account picked at consent,
# and refused by Fizzy's own API.
class OauthAudienceTest < ActionDispatch::IntegrationTest
  MCP_RESOURCE = "https://mcp.example.com/mcp"
  CODE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  setup do
    @previous_mcp_resources = Rails.application.config.x.oauth.mcp_resources
    Rails.application.config.x.oauth.mcp_resources = [ MCP_RESOURCE ]

    @client = oauth_clients(:mcp_client)
    @david_at_initech = accounts(:initech).users.create!(identity: identities(:david), name: "David", role: :member, verified_at: Time.current)
  end

  teardown do
    Rails.application.config.x.oauth.mcp_resources = @previous_mcp_resources
  end

  test "consent for the MCP resource asks which account to connect" do
    sign_in_as :david

    get_consent resource: MCP_RESOURCE

    assert_response :success
    assert_select "input[type=radio][name=account_id]", 2
    assert_select "input[type=radio][name=account_id][value=?]", accounts("37s").id
    assert_select "input[type=radio][name=account_id][value=?]", accounts(:initech).id
    assert_select "input[type=hidden][name=resource][value=?]", MCP_RESOURCE
  end

  test "consent without a resource, or naming Fizzy's own API, asks for no account" do
    sign_in_as :david

    [ nil, "http://www.example.com/", "http://www.example.com" ].each do |resource|
      get_consent resource: resource

      assert_response :success
      assert_select "select[name=account_id]", 0
      assert_select "input[name=resource]", 0
    end
  end

  test "an unknown resource is invalid_target" do
    sign_in_as :david

    [ "https://evil.example.com/mcp", "#{MCP_RESOURCE}/", " " ].each do |resource|
      get_consent resource: resource

      assert_response :redirect
      assert_equal "invalid_target", redirect_params["error"]
    end
  end

  # resource[]= is Rails' list syntax, not RFC 8707's repeated parameter (a
  # bare key repeated is invalid_target, below), so it's refused as a malformed
  # parameter by the single-valued check, before any audience is read.
  test "a resource or account_id sent as a list is invalid_request" do
    sign_in_as :david

    get_consent resource: [ MCP_RESOURCE, MCP_RESOURCE ]
    assert_response :redirect
    assert_equal "invalid_request", redirect_params["error"]
    assert_match "resource", redirect_params["error_description"]

    post_consent resource: MCP_RESOURCE, account_id: [ accounts(:initech).id ]
    assert_response :redirect
    assert_equal "invalid_request", redirect_params["error"]
    assert_match "account_id", redirect_params["error_description"]
    assert_nil redirect_params["code"]
  end

  test "a token request naming resource as a list is invalid_request" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts(:initech).id)

    redeem code, resource: [ MCP_RESOURCE ]

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body["error"]
    assert_match "resource", response.parsed_body["error_description"]
  end

  test "no resource is an MCP resource until one is configured" do
    Rails.application.config.x.oauth.mcp_resources = []
    sign_in_as :david

    get_consent resource: MCP_RESOURCE

    assert_response :redirect
    assert_equal "invalid_target", redirect_params["error"]
  end

  test "the account picked at consent and the audience are stamped on the grant and kept through rotation" do
    sign_in_as :david

    grant = connect(account: accounts(:initech))

    assert_equal MCP_RESOURCE, grant.audience
    assert_equal accounts(:initech).id, grant.account_id
    assert grant.audienced?
    assert grant.account_bound?

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: @token_response["refresh_token"] }, as: :json
    end

    assert_response :success
    grant.reload
    assert_equal MCP_RESOURCE, grant.audience
    assert_equal accounts(:initech).id, grant.account_id
  end

  test "a refresh may name the grant's own resource and no other" do
    sign_in_as :david
    connect(account: accounts("37s"))

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: @token_response["refresh_token"], resource: "http://www.example.com/" }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: @token_response["refresh_token"], resource: MCP_RESOURCE }, as: :json
    end

    assert_response :success
  end

  test "a refresh naming a whitespace resource is invalid_target, not taken as naming none" do
    sign_in_as :david
    connect(account: accounts("37s"))

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: @token_response["refresh_token"], resource: " " }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "a grant for an account the person has since left doesn't refresh" do
    sign_in_as :david
    connect(account: accounts(:initech))
    @david_at_initech.destroy

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: @token_response["refresh_token"] }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "an unaudienced grant can't be refreshed into an audienced one" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client)

    untenanted do
      post oauth_token_path, params: { grant_type: "refresh_token", client_id: @client.client_id, refresh_token: grant.raw_refresh_token, resource: MCP_RESOURCE }, as: :json
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
    assert_nil grant.reload.audience
  end

  test "a code redeems only with its own resource" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)

    assert_no_difference "Identity::AccessToken.count" do
      redeem code, resource: "https://evil.example.com/mcp"
    end
    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "an unaudienced code can't be redeemed for the MCP resource" do
    sign_in_as :david
    code = consent_code

    assert_no_difference "Identity::AccessToken.count" do
      redeem code, resource: MCP_RESOURCE
    end
    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "an unaudienced code redeems naming Fizzy's own API" do
    sign_in_as :david
    code = consent_code

    redeem code, resource: "http://www.example.com/"

    assert_response :success
    grant = Identity::AccessToken.find_by_raw_token(response.parsed_body["access_token"])
    assert_not grant.audienced?
    assert_not grant.account_bound?
  end

  test "consent refuses an account the person doesn't belong to" do
    sign_in_as :david

    post_consent resource: MCP_RESOURCE, account_id: accounts(:acme).id

    assert_response :bad_request
    assert_select "code", text: "invalid_request"
  end

  test "consent for the MCP resource tells the client no for someone with no account to connect" do
    sign_in_as Identity.create!(email_address: "nobody@example.com")

    get_consent resource: MCP_RESOURCE

    assert_response :redirect
    assert_equal "access_denied", redirect_params["error"]
  end

  test "an unvetted client is shown, not sent, that there's no account to connect" do
    sign_in_as Identity.create!(email_address: "nobody@example.com")
    @client = Oauth::Client.create!(name: "Hosted", redirect_uris: %w[ https://connector.example.com/callback ], scopes: %w[ read write ], dynamically_registered: true)

    get_consent resource: MCP_RESOURCE

    assert_response :bad_request
    assert_select "code", text: "access_denied"
  end

  test "a resource repeated as a bare key is invalid_target, not the last one named" do
    sign_in_as :david

    untenanted do
      get "#{new_oauth_authorization_path}?#{consent_params.to_query}&resource=#{CGI.escape(MCP_RESOURCE)}&resource=#{CGI.escape("http://www.example.com/")}"
    end

    assert_response :redirect
    assert_equal "invalid_target", redirect_params["error"]
  end

  test "a resource repeated as a bare key in a token request's form body is invalid_target" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)

    body = { grant_type: "authorization_code", client_id: @client.client_id, code: code,
      redirect_uri: @client.redirect_uris.first, code_verifier: CODE_VERIFIER }.to_query
    body += "&resource=#{CGI.escape("http://www.example.com/")}&resource=#{CGI.escape(MCP_RESOURCE)}"

    assert_no_difference "Identity::AccessToken.count" do
      untenanted do
        post oauth_token_path, params: body, headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
      end
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "denying an audienced request tells the client no, even with no account to connect" do
    sign_in_as Identity.create!(email_address: "nobody@example.com")

    post_consent resource: MCP_RESOURCE, error: "access_denied"

    assert_response :redirect
    assert_equal "access_denied", redirect_params["error"]
  end

  test "a resource repeated in a multipart token request is invalid_target" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)

    assert_no_difference "Identity::AccessToken.count" do
      untenanted do
        post oauth_token_path, **multipart(redeem_fields(code), resource: [ "http://www.example.com/", MCP_RESOURCE ])
      end
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "a resource repeated in a multipart refresh is invalid_target" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, audience: MCP_RESOURCE, account_id: accounts("37s").id)

    untenanted do
      post oauth_token_path, **multipart({ grant_type: "refresh_token", client_id: @client.client_id, refresh_token: grant.raw_refresh_token },
        resource: [ "http://www.example.com/", MCP_RESOURCE ])
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "a resource repeated as a JSON key is invalid_target, not the last one named" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)
    json = redeem_fields(code).to_json.delete_suffix("}") + %(,"resource":"http://www.example.com/","resource":"#{MCP_RESOURCE}"})

    assert_no_difference "Identity::AccessToken.count" do
      untenanted do
        post oauth_token_path, params: json, headers: { "CONTENT_TYPE" => "application/json" }
      end
    end

    assert_response :bad_request
    assert_equal "invalid_target", response.parsed_body["error"]
  end

  test "a resource in a multipart consent is invalid_target, however many times it's named" do
    sign_in_as :david

    [ [ MCP_RESOURCE ], [ "http://www.example.com/", MCP_RESOURCE ] ].each do |resources|
      untenanted do
        post oauth_authorization_path, **multipart(consent_params(account_id: accounts("37s").id), resource: resources)
      end

      assert_response :redirect
      assert_equal "invalid_target", redirect_params["error"]
    end
  end

  test "a resource in a multipart body of an authorization request is invalid_target" do
    sign_in_as :david
    request = multipart({}, resource: [ MCP_RESOURCE ])

    untenanted do
      get "#{new_oauth_authorization_path}?#{consent_params(resource: "http://www.example.com/").to_query}",
        env: { "CONTENT_TYPE" => request[:headers]["CONTENT_TYPE"], "rack.input" => StringIO.new(request[:params]) }
    end

    assert_response :redirect
    assert_equal "invalid_target", redirect_params["error"]
  end

  test "a resource sent once in a JSON or form body still redeems" do
    sign_in_as :david

    untenanted do
      post oauth_token_path, params: redeem_fields(consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)).merge(resource: MCP_RESOURCE).to_json,
        headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :success

    untenanted do
      post oauth_token_path, params: redeem_fields(consent_code(resource: MCP_RESOURCE, account_id: accounts("37s").id)).merge(resource: MCP_RESOURCE).to_query,
        headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    end
    assert_response :success
  end

  test "a code for an account the person has since left doesn't redeem" do
    sign_in_as :david
    code = consent_code(resource: MCP_RESOURCE, account_id: accounts(:initech).id)
    @david_at_initech.destroy

    assert_no_difference "Identity::AccessToken.count" do
      redeem code, resource: MCP_RESOURCE
    end
    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "Fizzy's API refuses an audienced token" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :write, audience: MCP_RESOURCE, account_id: accounts("37s").id)

    get user_path(users(:david)), env: bearer(grant), as: :json

    assert_response :unauthorized
    assert_match 'error="invalid_token"', response.headers["WWW-Authenticate"]
  end

  test "an account-bound token reaches its own account and no other" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, account_id: accounts("37s").id)

    get user_path(users(:david)), env: bearer(grant), as: :json
    assert_response :success

    get user_path(@david_at_initech, script_name: "/#{accounts(:initech).external_account_id}"), env: bearer(grant), as: :json
    assert_response :unauthorized
    assert_match 'error="invalid_token"', response.headers["WWW-Authenticate"]
  end

  test "an identity-wide token still reaches every account" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client)

    get user_path(@david_at_initech, script_name: "/#{accounts(:initech).external_account_id}"), env: bearer(grant), as: :json

    assert_response :success
  end

  test "outside any account, an account-bound token is refused unless the endpoint answers for its account alone" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, permission: :write, account_id: accounts("37s").id)

    untenanted do
      get my_access_tokens_path, env: bearer(grant), as: :json
    end

    assert_response :unauthorized
    assert_match 'error="invalid_token"', response.headers["WWW-Authenticate"]
  end

  test "my identity lists only the bound account to an account-bound token" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client, account_id: accounts(:initech).id)

    untenanted do
      get my_identity_path, env: bearer(grant), as: :json
    end

    assert_response :success
    assert_equal [ accounts(:initech).id ], response.parsed_body["accounts"].map { |account| account["id"] }
  end

  test "my identity lists every account to an identity-wide token" do
    grant = identities(:david).access_tokens.create!(oauth_client: @client)

    untenanted do
      get my_identity_path, env: bearer(grant), as: :json
    end

    assert_response :success
    assert_equal [ accounts("37s").id, accounts(:initech).id ].sort, response.parsed_body["accounts"].map { |account| account["id"] }.sort
  end

  test "only an operator-provisioned confidential client may front a protected resource" do
    public_client = Oauth::Client.new(name: "Public", redirect_uris: %w[ http://127.0.0.1:9999/cb ], protected_resource: MCP_RESOURCE)
    assert_not public_client.valid?
    assert public_client.errors.added?(:protected_resource, "may only be set on an operator-provisioned confidential client")

    registered = Oauth::Client.new(name: "Registered", redirect_uris: %w[ https://example.com/cb ], dynamically_registered: true,
      token_endpoint_auth_method: "client_secret_post", protected_resource: MCP_RESOURCE)
    assert_not registered.valid?

    provisioned = Oauth::Client.create!(name: "fizzy-mcp-server", redirect_uris: %w[ https://mcp.example.com/cb ],
      token_endpoint_auth_method: "client_secret_post", protected_resource: MCP_RESOURCE)
    assert provisioned.fronts?(MCP_RESOURCE)
    assert_not provisioned.fronts?("https://other.example.com/mcp")
    assert_not @client.fronts?(MCP_RESOURCE)
  end

  private
    def consent_params(**overrides)
      {
        client_id: @client.client_id,
        redirect_uri: @client.redirect_uris.first,
        response_type: "code",
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false),
        code_challenge_method: "S256",
        scope: "read write",
        state: "xyz123"
      }.merge(overrides).compact
    end

    def get_consent(**params)
      untenanted { get new_oauth_authorization_path, params: consent_params(**params) }
    end

    def post_consent(**params)
      untenanted { post oauth_authorization_path, params: consent_params(**params) }
    end

    def consent_code(**params)
      post_consent(**params)
      assert_response :redirect
      redirect_params.fetch("code")
    end

    def redeem(code, **params)
      untenanted do
        post oauth_token_path, params: { grant_type: "authorization_code", client_id: @client.client_id, code: code,
          redirect_uri: @client.redirect_uris.first, code_verifier: CODE_VERIFIER, **params }, as: :json
      end
    end

    def connect(account:)
      redeem consent_code(resource: MCP_RESOURCE, account_id: account.id), resource: MCP_RESOURCE
      assert_response :success
      @token_response = response.parsed_body
      Identity::AccessToken.find_by_raw_token(@token_response["access_token"])
    end

    def redeem_fields(code)
      { grant_type: "authorization_code", client_id: @client.client_id, code: code,
        redirect_uri: @client.redirect_uris.first, code_verifier: CODE_VERIFIER }
    end

    # A multipart/form-data body naming each field once, and resource once per value.
    def multipart(fields, resource:)
      boundary = "LaneBBoundary"
      parts = fields.map { |name, value| [ name.to_s, value.to_s ] } + resource.map { |value| [ "resource", value ] }
      body = parts.map { |name, value| "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n" }.join + "--#{boundary}--\r\n"

      { params: body, headers: { "CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}" } }
    end

    def redirect_params
      URI.decode_www_form(URI.parse(response.location).query).to_h
    end

    def bearer(grant)
      { "HTTP_AUTHORIZATION" => "Bearer #{grant.raw_token}" }
    end
end
