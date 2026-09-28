require "test_helper"

class ActionPack::WebAuthn::PublicKeyCredentialTest < ActiveSupport::TestCase
  # COSE CBOR for an Ed25519 (OKP/EdDSA) public key: {1: 1, 3: -8, -1: 6, -2: <x 32 bytes>}
  OKP_CBOR = [ "a4010103272006215820a95ee02872a2c5224b394832767bea746620e50776e8" \
    "45872228716065f16005" ].pack("H*")

  test "to_h serializes and round-trips an Ed25519 public key" do
    public_key = ActionPack::WebAuthn::CoseKey.decode(OKP_CBOR).to_openssl_key

    credential = ActionPack::WebAuthn::PublicKeyCredential.new(
      id: "credential-id", public_key: public_key, sign_count: 0
    )

    # Regression: Ed25519 keys decode to a generic OpenSSL::PKey::PKey with no
    # #to_der, which crashed to_h. public_to_der works for every key type and
    # round-trips back into a usable verification key.
    der = credential.to_h[:public_key]
    restored = OpenSSL::PKey.read(der)

    assert_equal "ED25519", restored.oid
  end

  test "to_h serializes and round-trips an EC public key" do
    public_key = OpenSSL::PKey::EC.generate("prime256v1")

    credential = ActionPack::WebAuthn::PublicKeyCredential.new(
      id: "credential-id", public_key: public_key, sign_count: 0
    )

    restored = OpenSSL::PKey.read(credential.to_h[:public_key])

    assert_instance_of OpenSSL::PKey::EC, restored
  end
end
