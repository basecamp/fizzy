require "test_helper"

class ActionPack::WebAuthn::Authenticator::AttestationResponseTest < ActiveSupport::TestCase
  # Auth data in all objects contains:
  #   rp_id_hash: SHA-256("example.com") (32 bytes)
  #   sign_count: 0
  #   aaguid: 00010203-0405-0607-0809-0a0b0c0d0e0f (16 bytes)
  #   credential_id: 32 sequential bytes 0x00..0x1f
  #   cose_key: EC2/ES256 P-256 {1: 2, 3: -7, -1: 1, -2: <x>, -3: <y>}

  # {"fmt": "none", "attStmt": {}, "authData": <flags: 0x45 (UP+UV+AT)>}
  ATTESTATION_NONE_VERIFIED = [ "a363666d74646e6f6e656761747453746d74a068617574684461" \
    "746158a4a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce1947" \
    "4500000000000102030405060708090a0b0c0d0e0f0020000102030405060708090a0b0c" \
    "0d0e0f101112131415161718191a1b1c1d1e1fa50102032620012158202ba472104c686f" \
    "39d4b623cc9324953e7053b47cae818e8cf774203a4f51af7122582069cb8ac519bdd929" \
    "e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  # {"fmt": "none", "attStmt": {}, "authData": <flags: 0x41 (UP+AT)>}
  ATTESTATION_NONE_NOT_VERIFIED = [ "a363666d74646e6f6e656761747453746d74a06861757468" \
    "4461746158a4a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586ce" \
    "19474100000000000102030405060708090a0b0c0d0e0f0020000102030405060708090a" \
    "0b0c0d0e0f101112131415161718191a1b1c1d1e1fa50102032620012158202ba472104c" \
    "686f39d4b623cc9324953e7053b47cae818e8cf774203a4f51af7122582069cb8ac519bd" \
    "d929e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  # {"fmt": "packed", "attStmt": {}, "authData": <flags: 0x45 (UP+UV+AT)>}
  ATTESTATION_PACKED_VERIFIED = [ "a363666d74667061636b65646761747453746d74a068617574" \
    "684461746158a4a379a6f6eeafb9a55e378c118034e2751e682fab9f2d30ab13d2125586" \
    "ce19474500000000000102030405060708090a0b0c0d0e0f0020000102030405060708090" \
    "a0b0c0d0e0f101112131415161718191a1b1c1d1e1fa50102032620012158202ba472104" \
    "c686f39d4b623cc9324953e7053b47cae818e8cf774203a4f51af7122582069cb8ac519b" \
    "dd929e2bdbe79e9f9b8d14c2d89a7cbd324647a1ccd68b8de3ca0" ].pack("H*")

  include WebauthnTestHelper

  setup do
    ActionPack::WebAuthn::Current.host = "example.com"

    @challenge = webauthn_challenge(purpose: "registration")
    @origin = "https://example.com"
    @client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    @response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin
    )
  end

  test "initializes with attestation object" do
    assert_not_nil @response.attestation_object
  end

  test "validate! succeeds with valid challenge, origin, and type" do
    assert_nothing_raised do
      @response.validate!
    end
  end

  test "validate! succeeds with user_verification preferred when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_NONE_NOT_VERIFIED,
      origin: @origin,
      user_verification: :preferred
    )

    assert_nothing_raised do
      response.validate!
    end
  end

  test "validate! succeeds with user_verification required when verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin,
      user_verification: :required
    )

    assert_nothing_raised do
      response.validate!
    end
  end

  test "validate! raises with user_verification required when not verified" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_NONE_NOT_VERIFIED,
      origin: @origin,
      user_verification: :required
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "User verification is required", error.message
  end

  test "validate! raises when type is not webauthn.create" do
    client_data_json = {
      challenge: @challenge,
      origin: @origin,
      type: "webauthn.get"
    }.to_json

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: client_data_json,
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Client data type is not webauthn.create", error.message
  end

  test "validate! raises when challenge in client data is invalid" do
    client_data_json = {
      challenge: "not-a-valid-signed-challenge",
      origin: @origin,
      type: "webauthn.create"
    }.to_json

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: client_data_json,
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_match /Challenge (is invalid|has expired)/, error.message
  end

  test "validate! raises when origin does not match" do
    @response.origin = "https://evil.com"

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      @response.validate!
    end

    assert_equal "Origin does not match", error.message
  end

  test "validate! raises when attestation format is not registered" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_PACKED_VERIFIED,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      response.validate!
    end

    assert_equal "Unsupported attestation format: packed", error.message
  end

  test "validate! raises for non-object client data instead of a 500" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: "123", # valid JSON, but not an object
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) { response.validate! }
    assert_equal "Client data is not a JSON object", error.message
  end

  test "validate! raises for a non-string challenge instead of a 500" do
    client_data_json = { challenge: { nested: "object" }, origin: @origin, type: "webauthn.create" }.to_json
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: client_data_json,
      attestation_object: ATTESTATION_NONE_VERIFIED,
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) { response.validate! }
    assert_match(/Challenge (is invalid|missing)/, error.message)
  end

  test "validate! raises for an attestation object that is not a CBOR map instead of a 500" do
    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: Base64.urlsafe_encode64("\x01".b, padding: false), # CBOR integer 1
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) { response.validate! }
    assert_equal "Malformed attestation object", error.message
  end

  test "raises for a non-string client data json or attestation object instead of a 500" do
    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
        client_data_json: 123, attestation_object: ATTESTATION_NONE_VERIFIED, origin: @origin
      )
    end

    assert_raises(ActionPack::WebAuthn::InvalidResponseError) do
      ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
        client_data_json: @client_data_json, attestation_object: 123, origin: @origin
      )
    end
  end

  test "accepts a predecoded Attestation instance, preserving Attestation.wrap's documented input" do
    # A library caller may decode once and hand the response an existing
    # Attestation (Attestation.wrap returns it as-is). The malformed-input guard
    # must not reject that supported branch.
    attestation = ActionPack::WebAuthn::Authenticator::Attestation.wrap(ATTESTATION_NONE_VERIFIED)

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: attestation,
      origin: @origin
    )

    assert_same attestation, response.attestation
    assert_nothing_raised { response.validate! }
  end

  test "validate! raises when attested credential data is missing (no AT flag)" do
    # Valid CBOR + binary authData, but flags 0x05 (UP+UV, no AT), so there is
    # no credential id / public key to persist. Must reject, not 500 on to_h.
    auth_data = Digest::SHA256.digest("example.com") + [ 0x05 ].pack("C") + [ 0 ].pack("N")

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: none_attestation_object(auth_data),
      origin: @origin
    )

    error = assert_raises(ActionPack::WebAuthn::InvalidResponseError) { response.validate! }
    assert_match(/Attested credential data is missing/, error.message)
  end

  # Builds a base64url "none" attestation object wrapping the given authData.
  def none_attestation_object(auth_data)
    cbor = "\xa3".b # map(3)
    cbor << "\x63".b << "fmt".b << "\x64".b << "none".b
    cbor << "\x67".b << "attStmt".b << "\xa0".b # {}
    cbor << "\x68".b << "authData".b << cbor_byte_string_header(auth_data.bytesize) << auth_data.b
    Base64.urlsafe_encode64(cbor, padding: false)
  end

  def cbor_byte_string_header(length)
    if length < 24
      [ 0x40 | length ].pack("C")
    elsif length < 256
      [ 0x58, length ].pack("C*")
    else
      [ 0x59 ].pack("C") + [ length ].pack("n")
    end
  end

  test "validate! calls registered verifier for custom format" do
    verified = false
    custom_verifier = Object.new
    custom_verifier.define_singleton_method(:verify!) { |_attestation, client_data_json:| verified = true }

    ActionPack::WebAuthn.register_attestation_verifier("packed", custom_verifier)

    response = ActionPack::WebAuthn::Authenticator::AttestationResponse.new(
      client_data_json: @client_data_json,
      attestation_object: ATTESTATION_PACKED_VERIFIED,
      origin: @origin
    )

    response.validate!
    assert verified
  ensure
    ActionPack::WebAuthn.attestation_verifiers.delete("packed")
  end
end
