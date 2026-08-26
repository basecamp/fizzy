require "test_helper"

class ActionPack::WebAuthnTest < ActiveSupport::TestCase
  test "every ceremony error descends from ActionPack::WebAuthn::Error" do
    # A single rescuable superclass lets callers turn any parse or verification
    # failure into a 4xx instead of an unhandled 500.
    [
      ActionPack::WebAuthn::InvalidResponseError,
      ActionPack::WebAuthn::InvalidCborError,
      ActionPack::WebAuthn::InvalidKeyError,
      ActionPack::WebAuthn::UnsupportedKeyTypeError,
      ActionPack::WebAuthn::InvalidOptionsError
    ].each do |error_class|
      assert_operator error_class, :<, ActionPack::WebAuthn::Error
    end
  end
end
