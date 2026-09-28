require "test_helper"

class UuidPrimaryKeyTest < ActiveSupport::TestCase
  test "new record is assigned a generated uuid primary key" do
    assert_match(/\A[0-9a-z]{25}\z/, Identity.new.id)
  end

  test "created record persists its generated uuid primary key" do
    identity = Identity.create!(email_address: "uuid-default@example.com")

    assert_equal identity.id, Identity.find_by(email_address: "uuid-default@example.com").id
  end
end
