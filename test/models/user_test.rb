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

  test "name methods handle blank names gracefully" do
    user = User.new(name: "")
    assert_equal "", user.familiar_name
    assert_nil user.first_name
    assert_nil user.last_name
    assert_equal "", user.initials
  end

  test "validates name presence" do
    user = User.new(account: accounts("37s"), role: "member", name: "")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"

    user.name = "   "
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"

    user.name = "Victor Cooper"
    assert user.valid?
  end

  test "setup?" do
    user = users(:kevin)

    user.update!(name: user.identity.email_address)
    assert_not user.setup?

    user.update!(name: "Kevin")
    assert user.setup?
  end

  test "verified? returns true when verified_at is present" do
    user = users(:david)
    user.update_column(:verified_at, Time.current)

    assert user.verified?
  end

  test "verified? returns false when verified_at is nil" do
    user = users(:david)
    user.update_column(:verified_at, nil)

    assert_not user.verified?
  end

  test "verify sets verified_at when not already verified" do
    user = users(:david)
    user.update_column(:verified_at, nil)

    assert_nil user.verified_at
    user.verify
    assert_not_nil user.reload.verified_at
  end

  test "verify does not update verified_at when already verified" do
    user = users(:david)
    original_time = 1.day.ago
    user.update_column(:verified_at, original_time)

    user.verify
    assert_equal original_time.to_i, user.reload.verified_at.to_i
  end
end
