require "test_helper"

class MagicLink::CodeTest < ActiveSupport::TestCase
  test "generate" do
    code = MagicLink::Code.generate(6)

    assert_equal 6, code.length
    assert_match(/\A[#{SecureRandom::BASE32_ALPHABET.join}]+\z/, code)
  end

  test "sanitize" do
    assert_equal "011123", MagicLink::Code.sanitize("OIL123")
    assert_equal "ABC123", MagicLink::Code.sanitize("ABC-123 !@#")
    assert_nil MagicLink::Code.sanitize(nil)
    assert_nil MagicLink::Code.sanitize("")
  end
end
