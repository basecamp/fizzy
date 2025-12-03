require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "create" do
    user = User.create!(
      account: accounts("37s"),
      role: "member",
      name: "Victor Cooper"
    )

    assert_equal [ boards(:writebook) ], user.boards
    assert user.settings.present?
  end

  test "creation gives access to all_access boards" do
    user = User.create!(
      account: accounts("37s"),
      role: "member",
      name: "Victor Cooper"
    )

    assert_equal [ boards(:writebook) ], user.boards
  end

  test "deactivate" do
    assert_changes -> { users(:jz).active? }, from: true, to: false do
      assert_changes -> { users(:jz).accesses.count }, from: 1, to: 0 do
        users(:jz).tap do |user|
          user.stubs(:close_remote_connections).once
          user.deactivate
        end
      end
    end
  end

  test "initials" do
    assert_equal "JF", User.new(name: "jason fried").initials
    assert_equal "DHH", User.new(name: "David Heinemeier Hansson").initials
    assert_equal "ÉLH", User.new(name: "Éva-Louise Hernández").initials
  end

  test "setup?" do
    user = users(:kevin)

    user.update!(name: user.identity.email_address)
    assert_not user.setup?

    user.update!(name: "Kevin")
    assert user.setup?
  end
end
