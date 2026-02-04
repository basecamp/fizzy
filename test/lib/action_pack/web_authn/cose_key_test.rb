require "test_helper"

class ActionPack::WebAuthn::CoseKeyTest < ActiveSupport::TestCase
  setup do
    # Generate a real EC key for valid test data
    ec_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_key_bn = ec_key.public_key.to_bn
    public_key_bytes = public_key_bn.to_s(2)
    # Skip the 0x04 uncompressed point prefix
    @ec2_x = public_key_bytes[1, 32]
    @ec2_y = public_key_bytes[33, 32]

    @ec2_parameters = {
      1 => 2,    # kty: EC2
      3 => -7,   # alg: ES256
      -1 => 1,   # crv: P-256
      -2 => @ec2_x,
      -3 => @ec2_y
    }

    # Generate a real RSA key for valid test data
    rsa_key = OpenSSL::PKey::RSA.new(2048)
    @rsa_n = rsa_key.n.to_s(2)
    @rsa_e = rsa_key.e.to_s(2)

    @rsa_parameters = {
      1 => 3,     # kty: RSA
      3 => -257,  # alg: RS256
      -1 => @rsa_n,
      -2 => @rsa_e
    }
  end

  test "initializes with key type, algorithm, and parameters" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: @ec2_parameters
    )

    assert_equal 2, key.key_type
    assert_equal(-7, key.algorithm)
    assert_equal @ec2_parameters, key.parameters
  end

  test "decodes EC2/ES256 key from CBOR" do
    cbor = encode_cbor(@ec2_parameters)
    key = ActionPack::WebAuthn::CoseKey.decode(cbor)

    assert_equal 2, key.key_type
    assert_equal(-7, key.algorithm)
  end

  test "decodes RSA/RS256 key from CBOR" do
    cbor = encode_cbor(@rsa_parameters)
    key = ActionPack::WebAuthn::CoseKey.decode(cbor)

    assert_equal 3, key.key_type
    assert_equal(-257, key.algorithm)
  end

  test "converts EC2/ES256 key to OpenSSL EC key" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: @ec2_parameters
    )

    openssl_key = key.to_openssl_key

    assert_instance_of OpenSSL::PKey::EC, openssl_key
    assert_equal "prime256v1", openssl_key.group.curve_name
  end

  test "converts RSA/RS256 key to OpenSSL RSA key" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 3,
      algorithm: -257,
      parameters: @rsa_parameters
    )

    openssl_key = key.to_openssl_key

    assert_instance_of OpenSSL::PKey::RSA, openssl_key
    assert_equal 65537, openssl_key.e.to_i
  end

  test "raises error for unsupported key type/algorithm combination" do
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 99,
      algorithm: -7,
      parameters: {}
    )

    error = assert_raises(ActionPack::WebAuthn::CoseKey::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/99\/-7/, error.message)
  end

  test "raises error for unsupported EC curve" do
    parameters = @ec2_parameters.merge(-1 => 2) # P-384 instead of P-256
    key = ActionPack::WebAuthn::CoseKey.new(
      key_type: 2,
      algorithm: -7,
      parameters: parameters
    )

    error = assert_raises(ActionPack::WebAuthn::CoseKey::UnsupportedKeyTypeError) do
      key.to_openssl_key
    end

    assert_match(/curve/, error.message.downcase)
  end

  private
    def encode_cbor(hash)
      # CBOR map encoding
      bytes = [ 0xa0 + hash.size ] # map with n items

      hash.each do |key, value|
        bytes.concat(encode_cbor_integer(key))
        bytes.concat(encode_cbor_value(value))
      end

      bytes.pack("C*")
    end

    def encode_cbor_integer(int)
      if int >= 0 && int <= 23
        [ int ]
      elsif int >= 0 && int <= 255
        [ 0x18, int ]
      elsif int >= -24 && int < 0
        [ 0x20 - int - 1 ]
      elsif int >= -256 && int < -24
        [ 0x38, -int - 1 ]
      else
        # 16-bit negative integer
        val = -int - 1
        [ 0x39, (val >> 8) & 0xff, val & 0xff ]
      end
    end

    def encode_cbor_value(value)
      case value
      when Integer
        encode_cbor_integer(value)
      when String
        length = value.bytesize
        if length <= 23
          [ 0x40 + length, *value.bytes ]
        elsif length <= 255
          [ 0x58, length, *value.bytes ]
        else
          [ 0x59, (length >> 8) & 0xff, length & 0xff, *value.bytes ]
        end
      end
    end
end
