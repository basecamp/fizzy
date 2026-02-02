require "test_helper"

class Fizzy::Saas::IdentityTest < ActiveSupport::TestCase
  test "#employee? returns true for 37signals.com domains" do
    identity = Identity.new(email_address: "mike@37signals.com")
    assert_predicate identity, :employee?
  end

  test "#employee? returns true for basecamp.com domains" do
    identity = Identity.new(email_address: "mike@basecamp.com")
    assert_predicate identity, :employee?
  end

  test "#employee? returns false for other domains" do
    identity = Identity.new(email_address: "mike@example.com")
    assert_not_predicate identity, :employee?
  end
end
