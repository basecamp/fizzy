require "test_helper"

class SingleSignOn::AuthorizationRequestTest < ActiveSupport::TestCase
  REDIRECT_URI = "https://fizzy.example.com/session/single_sign_on/callback"

  setup do
    enable_single_sign_on
    stub_single_sign_on_provider
    @request = SingleSignOn::AuthorizationRequest.start(return_to: "https://fizzy.example.com/1/boards")
  end

  teardown do
    disable_single_sign_on
  end

  test "start" do
    assert_operator @request.state.length, :>=, 43
    assert_operator @request.nonce.length, :>=, 43
    assert_operator @request.code_verifier.length, :>=, 43
    assert_not_equal @request.state, @request.nonce
    assert_not @request.expired?
  end

  test "round trip" do
    restored = SingleSignOn::AuthorizationRequest.from_h(JSON.parse(@request.to_h.to_json))

    assert_equal @request.to_h, restored.to_h
    assert_equal "https://fizzy.example.com/1/boards", restored.return_to
  end

  test "a return address over 2 KB is dropped" do
    return_to = "https://fizzy.example.com/1/boards?#{"a" * 2.kilobytes}"

    assert_nil SingleSignOn::AuthorizationRequest.start(return_to: return_to).return_to
  end

  test "URL carries the state, the nonce, and an S256 code challenge" do
    parameters = Rack::Utils.parse_query(URI(@request.url(redirect_uri: REDIRECT_URI)).query)

    assert_equal @request.state, parameters["state"]
    assert_equal @request.nonce, parameters["nonce"]
    assert_equal Base64.urlsafe_encode64(Digest::SHA256.digest(@request.code_verifier), padding: false),
      parameters["code_challenge"]
  end

  test "complete" do
    stub_single_sign_on_token_exchange single_sign_on_id_token(nonce: @request.nonce)

    claims = complete(code: "fizzy-code", state: @request.state, iss: SINGLE_SIGN_ON_ISSUER)

    assert_equal "kevin-subject", claims.subject
    assert_requested :post, SINGLE_SIGN_ON_TOKEN_ENDPOINT, body: hash_including(code_verifier: @request.code_verifier)
  end

  test "expired request" do
    travel SingleSignOn::AuthorizationRequest::EXPIRATION_TIME + 1.minute

    assert @request.expired?
    assert_raises(SingleSignOn::AuthorizationError) { complete(code: "fizzy-code") }
  end

  test "error response" do
    assert_raises(SingleSignOn::AuthorizationError) { complete(error: "access_denied") }
  end

  test "response from another issuer" do
    assert_raises(SingleSignOn::AuthorizationError) do
      complete(code: "fizzy-code", iss: "https://other.example.com")
    end
  end

  test "response without a code" do
    assert_raises(SingleSignOn::AuthorizationError) { complete(state: @request.state) }
  end

  private
    def complete(**params)
      @request.complete(ActionController::Parameters.new(params), redirect_uri: REDIRECT_URI)
    end
end
