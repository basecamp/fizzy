require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "create" do
    user = User.create! \
      account: accounts("37s"),
      role: "member",
      name: "Victor Cooper",
      email_address: "victor@hey.com",
      password: "secret123456"

    assert_equal accounts("37s"), user.account
    assert_equal user, User.authenticate_by(email_address: "victor@hey.com", password: "secret123456")
  end

  test "creation gives access to all_access collections" do
    user = User.create! \
      account: accounts("37s"),
      role: "member",
      name: "Victor Cooper",
      email_address: "victor@hey.com",
      password: "secret123456"

    assert_equal [ collections(:writebook) ], user.collections
  end

  test "deactivate" do
    assert_changes -> { users(:jz).active? }, from: true, to: false do
      users(:jz).deactivate
    end
  end

  test "initials" do
    assert_equal "JF", User.new(name: "jason fried").initials
    assert_equal "DHH", User.new(name: "David Heinemeier Hansson").initials
    assert_equal "ÉLH", User.new(name: "Éva-Louise Hernández").initials
  end

  test "system user" do
    system_user = accounts("37s").users.system

    assert system_user.system?
    assert_equal "System", system_user.name
    assert_equal "S", system_user.initials

    assert_not_includes User.active, system_user
  end
end
