require "test_helper"

class ActionPack::WebAuthn::RelyingPartyTest < ActiveSupport::TestCase
  test "initializes with explicit id and name" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")

    assert_equal "example.com", relying_party.id
    assert_equal "Example App", relying_party.name
  end

  test "initializes with default id from Current.host" do
    ActionPack::WebAuthn::Current.set(host: "default.example.com") do
      relying_party = ActionPack::WebAuthn::RelyingParty.new(name: "Example App")

      assert_equal "default.example.com", relying_party.id
    end
  end

  test "initializes with default name from Rails application" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com")

    assert_equal Rails.application.name, relying_party.name
  end

  test "as_json returns id and name" do
    relying_party = ActionPack::WebAuthn::RelyingParty.new(id: "example.com", name: "Example App")

    assert_equal({ id: "example.com", name: "Example App" }, relying_party.as_json)
  end
end
