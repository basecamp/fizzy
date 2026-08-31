# = Action Pack WebAuthn CBOR Decoder
#
# Decodes Concise Binary Object Representation (CBOR) data as specified in
# RFC 8949[https://tools.ietf.org/html/rfc8949]. CBOR is a binary data format
# used by WebAuthn for encoding authenticator data and attestation objects.
#
# == Usage
#
# The decoder accepts either a binary string or an array of bytes:
#
#   # From binary string
#   ActionPack::WebAuthn::CborDecoder.decode("\x83\x01\x02\x03")
#   # => [1, 2, 3]
#
#   # From byte array
#   ActionPack::WebAuthn::CborDecoder.decode([0x83, 0x01, 0x02, 0x03])
#   # => [1, 2, 3]
#
# == Supported Types
#
# The decoder supports the following CBOR types:
#
# [Integers]
#   Unsigned (major type 0) and negative (major type 1) integers of any size.
#
# [Byte strings]
#   Binary data (major type 2), returned as ASCII-8BIT encoded strings.
#
# [Text strings]
#   UTF-8 text (major type 3), returned as UTF-8 encoded strings.
#
# [Arrays]
#   Ordered collections (major type 4) of any CBOR values.
#
# [Maps]
#   Key-value pairs (major type 5) with any CBOR values as keys and values.
#
# [Floats]
#   IEEE 754 half (16-bit), single (32-bit), and double (64-bit) precision.
#
# [Simple values]
#   +false+, +true+, +null+, and +undefined+ (both decoded as +nil+).
#
# [Indefinite length]
#   Streaming byte strings, text strings, arrays, and maps.
#
# Tags (major type 6) are recognized but their semantic meaning is ignored;
# the tagged value is returned directly.
#
# == Errors
#
# Raises +InvalidCborError+ when encountering malformed or unsupported CBOR data.
class ActionPack::WebAuthn::CborDecoder
  # Major types
  UNSIGNED_INTEGER_TYPE = 0
  NEGATIVE_INTEGER_TYPE = 1
  BYTE_STRING_TYPE = 2
  TEXT_STRING_TYPE = 3
  ARRAY_TYPE = 4
  MAP_TYPE = 5
  TAG_TYPE = 6
  FLOAT_OR_SIMPLE_TYPE = 7

  # Additional information values
  SIMPLE_VALUE_RANGE = 0..23
  SINGLE_BYTE_VALUE_FOLLOWS = 24
  TWO_BYTE_VALUE_FOLLOWS = 25
  FOUR_BYTE_VALUE_FOLLOWS = 26
  EIGHT_BYTE_VALUE_FOLLOWS = 27
  RESERVED_VALUE_RANGE = 28..30
  INDEFINITE_LENGTH_MAJOR_TYPE = 31

  # Simple values
  SIMPLE_FALSE_VALUE = 20
  SIMPLE_TRUE_VALUE = 21
  SIMPLE_NULL_VALUE = 22
  SIMPLE_UNDEFINED_VALUE = 23

  # Flow control
  BREAK_CODE = 0xFF

  # Limits
  MAX_DEPTH = 16
  MAX_SIZE = 10.megabytes

  # Caps the total number of container elements (array entries and map pairs)
  # decoded from a single input. The byte-size limit alone is not enough: a
  # definite-length array of millions of one-byte items, or an indefinite-length
  # container of the same, stays under MAX_SIZE yet forces the decoder to build
  # millions of Ruby objects (hundreds of MB) before any later type check can
  # reject it. Real WebAuthn attestation objects hold only a handful of elements,
  # so this ceiling is generous while still bounding worst-case allocation.
  MAX_ELEMENTS = 65_536

  # Tags
  POSITIVE_BIGNUM_TAG = 2
  NEGATIVE_BIGNUM_TAG = 3

  class << self
    # Decodes a CBOR-encoded byte sequence into a Ruby object.
    #
    #   ActionPack::WebAuthn::CborDecoder.decode("\xa2\x61a\x01\x61b\x02")
    #   # => {"a" => 1, "b" => 2}
    def decode(bytes, **args)
      bytes = bytes.bytes if bytes.respond_to?(:bytes)
      new(bytes, **args).decode
    end
  end

  def initialize(bytes, max_depth: MAX_DEPTH, max_size: MAX_SIZE, max_elements: MAX_ELEMENTS) # :nodoc:
    raise ActionPack::WebAuthn::InvalidCborError, "Input exceeds maximum size" if bytes.length > max_size

    @bytes = bytes
    @max_depth = max_depth
    @max_elements = max_elements
    @position = 0
    @depth = 0
    @element_count = 0
  end

  # Decodes the next CBOR data item from the byte sequence.
  def decode
    raise ActionPack::WebAuthn::InvalidCborError, "Unexpected end of input" if @position >= @bytes.length
    raise ActionPack::WebAuthn::InvalidCborError, "Maximum nesting depth exceeded" if @depth >= @max_depth

    @depth += 1

    result = case major_type
    when UNSIGNED_INTEGER_TYPE then decode_unsigned_integer
    when NEGATIVE_INTEGER_TYPE then decode_negative_integer
    when BYTE_STRING_TYPE then decode_byte_string
    when TEXT_STRING_TYPE then decode_text_string
    when ARRAY_TYPE then decode_array
    when MAP_TYPE then decode_map
    when TAG_TYPE then decode_tag
    when FLOAT_OR_SIMPLE_TYPE then decode_float_or_simple
    end

    @depth -= 1
    result
  end

  private
    def major_type
      peek >> 5
    end

    def peek
      @bytes[@position]
    end

    def decode_unsigned_integer
      read_argument
    end

    def decode_negative_integer
      -1 - read_argument
    end

    def decode_byte_string
      if indefinite_length?
        String.new(encoding: Encoding::ASCII_8BIT).tap { |str| str << decode_byte_string until break_code? }
      else
        read_bytes(read_argument).pack("C*")
      end
    end

    def decode_text_string
      if indefinite_length?
        String.new(encoding: Encoding::UTF_8).tap { |str| str << decode_text_string until break_code? }
      else
        read_bytes(read_argument).pack("C*").force_encoding(Encoding::UTF_8)
      end
    end

    def decode_array
      if indefinite_length?
        # No declared count to charge up front, so charge each element as it
        # arrives to bound an indefinite stream of tiny items.
        Array.new.tap { |arr| arr << decode_element until break_code? }
      else
        # Build incrementally rather than Array.new(count) { ... }: a declared
        # count must not pre-size the backing store. read_length caps the count
        # at the remaining bytes and against the element budget, rejecting an
        # oversized declaration before a single element is built.
        Array.new.tap { |arr| read_length.times { arr << decode } }
      end
    end

    def decode_map
      if indefinite_length?
        # decode_element charges the pair as the key arrives; the break check
        # runs first, so a closing 0xFF is never charged.
        Hash.new.tap { |hash| hash[decode_element] = decode until break_code? }
      else
        Hash.new.tap do |hash|
          read_length.times do
            hash[decode] = decode
          end
        end
      end
    end

    # Decodes one element of an indefinite-length container, charging it against
    # the element budget first so the stream is bounded even without a declared
    # length.
    def decode_element
      charge_element
      decode
    end

    # Charges +count+ elements against the running budget, rejecting the input
    # once the total would exceed MAX_ELEMENTS. Mirrors the byte-size ceiling:
    # a bound on how much the decoder will allocate, independent of the declared
    # or streamed shape of the data.
    def charge_element(count = 1)
      @element_count += count

      if @element_count > @max_elements
        raise ActionPack::WebAuthn::InvalidCborError, "Decoded element count exceeds maximum"
      end
    end

    def decode_float_or_simple
      case info = additional_info
      when SIMPLE_FALSE_VALUE then false
      when SIMPLE_TRUE_VALUE then true
      when SIMPLE_NULL_VALUE, SIMPLE_UNDEFINED_VALUE then nil
      when TWO_BYTE_VALUE_FOLLOWS then decode_half_float
      when FOUR_BYTE_VALUE_FOLLOWS then read_bytes(4).pack("C*").unpack1("g")
      when EIGHT_BYTE_VALUE_FOLLOWS then read_bytes(8).pack("C*").unpack1("G")
      else
        raise ActionPack::WebAuthn::InvalidCborError, "Invalid simple value: #{info}"
      end
    end

    def decode_tag
      tag = read_argument
      value = decode

      case tag
      when POSITIVE_BIGNUM_TAG then value.bytes.inject(0) { |n, b| (n << 8) | b }
      when NEGATIVE_BIGNUM_TAG then -1 - value.bytes.inject(0) { |n, b| (n << 8) | b }
      else value
      end
    end

    def decode_half_float
      half = read_bytes(2).pack("C*").unpack1("n")

      sign = (half >> 15) & 0x1
      exponent = (half >> 10) & 0x1F
      mantissa = half & 0x3FF

      value = if exponent == 0
        Math.ldexp(mantissa, -24)
      elsif exponent == 31
        mantissa == 0 ? Float::INFINITY : Float::NAN
      else
        Math.ldexp(mantissa + 1024, exponent - 25)
      end

      sign == 1 ? -value : value
    end

    def read_argument
      case info = additional_info
      when SIMPLE_VALUE_RANGE then info
      when SINGLE_BYTE_VALUE_FOLLOWS then read_byte
      when TWO_BYTE_VALUE_FOLLOWS then read_bytes(2).pack("C*").unpack1("n")
      when FOUR_BYTE_VALUE_FOLLOWS then read_bytes(4).pack("C*").unpack1("N")
      when EIGHT_BYTE_VALUE_FOLLOWS then read_bytes(8).pack("C*").unpack1("Q>")
      when RESERVED_VALUE_RANGE
        raise ActionPack::WebAuthn::InvalidCborError, "Reserved additional info: #{info}"
      else
        raise ActionPack::WebAuthn::InvalidCborError, "Invalid additional info: #{info}"
      end
    end

    def additional_info(consume: true)
      byte = consume ? read_byte : peek
      byte & 0b00011111
    end

    def indefinite_length?
      read_byte if additional_info(consume: false) == INDEFINITE_LENGTH_MAJOR_TYPE
    end

    def break_code?
      read_byte if peek == BREAK_CODE
    end

    # Reads a definite-length container's element count and rejects any count
    # that exceeds the number of bytes left to read. Every CBOR data item
    # occupies at least one byte, so a well-formed array or map can never
    # declare more elements than there are remaining bytes. Without this bound
    # a tiny input can name a multi-billion element array (e.g. 0x9a ff ff ff
    # ff) and drive an out-of-memory pre-allocation before decoding begins.
    def read_length
      length = read_argument

      if length > @bytes.length - @position
        raise ActionPack::WebAuthn::InvalidCborError, "Declared length exceeds remaining input"
      end

      # Charge the whole declared count before decoding any element, so an
      # array or map that names millions of one-byte items is rejected up front
      # rather than after the backing store has already been grown.
      charge_element(length)

      length
    end

    def read_bytes(length)
      raise ActionPack::WebAuthn::InvalidCborError, "Unexpected end of input" if @position + length > @bytes.length

      bytes = @bytes[@position, length]
      @position += length
      bytes
    end

    def read_byte
      raise ActionPack::WebAuthn::InvalidCborError, "Unexpected end of input" if @position >= @bytes.length

      byte = @bytes[@position]
      @position += 1
      byte
    end
end
