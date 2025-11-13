require "test_helper"

class User::AccessorTest < ActiveSupport::TestCase
  test "new users get added to all_access boards on creation" do
    user = User.create!(account: accounts("37s"), name: "Jorge")

    assert_includes user.boards, boards(:writebook)
    assert_equal user.account.boards.all_access.count, user.boards.count
  end

  test "system user does not get added to boards on creation" do
    system_user = User.create!(account: accounts("37s"), role: "system", name: "Test System User")
    assert_empty system_user.boards
  end
end
