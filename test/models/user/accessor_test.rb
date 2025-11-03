require "test_helper"

class User::AccessorTest < ActiveSupport::TestCase
  test "new users get added to all_access collections on creation" do
    user = User.create!(name: "Jorge", email_address: "testregular@example.com")

    assert_includes user.collections, collections(:writebook)
    assert_equal Collection.all_access.count, user.collections.count
  end

  test "system user does not get added to collections on creation" do
    system_user = User.create!(role: "system", name: "Test System User")
    assert_empty system_user.collections
  end
end
