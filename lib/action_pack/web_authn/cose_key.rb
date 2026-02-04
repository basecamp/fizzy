# = Action Pack WebAuthn COSE Key
#
# Parses COSE (CBOR Object Signing and Encryption) public keys as specified in
# RFC 9053[https://datatracker.ietf.org/doc/html/rfc9053]. WebAuthn authenticators
# return public keys in COSE format, which must be converted to a standard format
# for signature verification.
#
# == Usage
#
#   # Decode a COSE key from CBOR bytes (e.g., from authenticator data)
#   cose_key = ActionPack::WebAuthn::CoseKey.decode(cbor_bytes)
#
#   # Convert to OpenSSL key for signature verification
#   openssl_key = cose_key.to_openssl_key
#   openssl_key.verify("SHA256", signature, signed_data)
#
# == Supported Algorithms
#
# [ES256]
#   ECDSA with P-256 curve and SHA-256. The most common algorithm for WebAuthn.
#
# [RS256]
#   RSASSA-PKCS1-v1_5 with SHA-256. Used by some security keys and platforms.
#
# == Attributes
#
# [+key_type+]
#   The COSE key type (2 for EC2, 3 for RSA).
#
# [+algorithm+]
#   The COSE algorithm identifier (-7 for ES256, -257 for RS256).
#
# [+parameters+]
#   The full COSE key parameters map, including curve and coordinate data.
class ActionPack::WebAuthn::CoseKey
  # Raised when the key type, algorithm, or curve is not supported.
  class UnsupportedKeyTypeError < StandardError; end

  # COSE key labels
  KTY_LABEL = 1
  ALG_LABEL = 3

  # COSE key types
  EC2 = 2
  RSA = 3

  # COSE algorithms
  ES256 = -7
  RS256 = -257

  # COSE EC2 curves
  P256 = 1

  attr_reader :key_type, :algorithm, :parameters

  class << self
    # Decodes a COSE key from CBOR-encoded bytes.
    #
    #   cose_key = ActionPack::WebAuthn::CoseKey.decode(cbor_bytes)
    #   cose_key.algorithm # => -7 (ES256)
    def decode(bytes)
      data = ActionPack::WebAuthn::CborDecoder.decode(bytes)
      new(
        key_type: data[KTY_LABEL],
        algorithm: data[ALG_LABEL],
        parameters: data
      )
    end
  end

  def initialize(key_type:, algorithm:, parameters:) # :nodoc:
    @key_type = key_type
    @algorithm = algorithm
    @parameters = parameters
  end

  # Converts the COSE key to an OpenSSL public key object.
  #
  # Returns an +OpenSSL::PKey::EC+ for EC2 keys or +OpenSSL::PKey::RSA+ for
  # RSA keys, suitable for use with +OpenSSL::PKey#verify+.
  #
  # Raises +UnsupportedKeyTypeError+ if the key type, algorithm, or curve
  # is not supported.
  def to_openssl_key
    case [ key_type, algorithm ]
    when [ EC2, ES256 ] then build_ec2_es256_key
    when [ RSA, RS256 ] then build_rsa_rs256_key
    else raise UnsupportedKeyTypeError, "Unsupported COSE key type/algorithm: #{key_type}/#{algorithm}"
    end
  end

  private
    def build_ec2_es256_key
      curve = parameters[-1]
      raise UnsupportedKeyTypeError, "Unsupported EC curve: #{curve}" unless curve == P256

      x = parameters[-2]
      y = parameters[-3]

      # Uncompressed point format: 0x04 || x || y
      public_key_bytes = [ 0x04, *x.bytes, *y.bytes ].pack("C*")

      asn1 = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::ObjectId("id-ecPublicKey"),
          OpenSSL::ASN1::ObjectId("prime256v1")
        ]),
        OpenSSL::ASN1::BitString(public_key_bytes)
      ])

      OpenSSL::PKey::EC.new(asn1.to_der)
    end

    def build_rsa_rs256_key
      n = OpenSSL::BN.new(parameters[-1], 2)
      e = OpenSSL::BN.new(parameters[-2], 2)

      asn1 = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Sequence([
          OpenSSL::ASN1::ObjectId("rsaEncryption"),
          OpenSSL::ASN1::Null.new(nil)
        ]),
        OpenSSL::ASN1::BitString(
          OpenSSL::ASN1::Sequence([
            OpenSSL::ASN1::Integer(n),
            OpenSSL::ASN1::Integer(e)
          ]).to_der
        )
      ])

      OpenSSL::PKey::RSA.new(asn1.to_der)
    end
end
