require "test_helper"

class User::RoleTest < ActiveSupport::TestCase
  test "can administer others?" do
    assert users(:kevin).can_administer?(users(:jz))

    assert_not users(:kevin).can_administer?(users(:kevin))
    assert_not users(:jz).can_administer?(users(:kevin))
  end

  test "owner can administer admins and members" do
    assert users(:jason).can_administer?(users(:kevin))
    assert users(:jason).can_administer?(users(:david))
    assert users(:jason).can_administer?(users(:jz))
  end

  test "owner cannot administer themselves" do
    assert_not users(:jason).can_administer?(users(:jason))
  end

  test "admin cannot administer the owner" do
    assert_not users(:kevin).can_administer?(users(:jason))
  end

  test "owner is included in active scope" do
    active_users = User.active
    assert_includes active_users, users(:jason)
    assert_includes active_users, users(:kevin)
    assert_includes active_users, users(:david)
    assert_not_includes active_users, users(:system)
  end

  test "owner is also considered an admin" do
    assert users(:jason).owner?
    assert users(:jason).admin?

    assert users(:kevin).admin?
    assert_not users(:kevin).owner?
  end

  test "owner scope returns only active owners" do
    owners = accounts("37s").users.owner
    assert_includes owners, users(:jason)
    assert_not_includes owners, users(:kevin)
    assert_not_includes owners, users(:david)

    users(:jason).update!(active: false)
    assert_not_includes accounts("37s").users.owner, users(:jason)
  end

  test "admin scope returns active owners and admins" do
    admins = accounts("37s").users.admin
    assert_includes admins, users(:jason)
    assert_includes admins, users(:kevin)
    assert_not_includes admins, users(:david)

    users(:kevin).update!(active: false)
    assert_not_includes accounts("37s").users.admin, users(:kevin)
  end

  test "system scope returns only system users" do
    system_users = User.system
    assert_includes system_users, users(:system)
    assert_not_includes system_users, users(:jason)
    assert_not_includes system_users, users(:kevin)
    assert_not_includes system_users, users(:david)
  end

  test "non_system scope returns only non-system users" do
    non_system_users = User.non_system
    assert_includes non_system_users, users(:jason)
    assert_includes non_system_users, users(:kevin)
    assert_includes non_system_users, users(:david)
    assert_not_includes non_system_users, users(:system)
  end

  test "can administer board?" do
    writebook_board = boards(:writebook)
    private_board = boards(:private)

    # Admin can administer any board
    assert users(:kevin).can_administer_board?(writebook_board)
    assert users(:kevin).can_administer_board?(private_board)

    # Creator can administer their own board
    assert users(:david).can_administer_board?(writebook_board)

    # Regular user cannot administer boards they didn't create
    assert_not users(:jz).can_administer_board?(writebook_board)
    assert_not users(:jz).can_administer_board?(private_board)

    # Creator cannot administer other people's boards
    assert_not users(:david).can_administer_board?(private_board)
  end

  test "can administer card?" do
    logo_card = cards(:logo)
    text_card = cards(:text)

    # Admin can administer any card
    assert users(:kevin).can_administer_card?(logo_card)
    assert users(:kevin).can_administer_card?(text_card)

    # Creator can administer their own card
    assert users(:david).can_administer_card?(logo_card)

    # Regular user cannot administer cards they didn't create
    assert_not users(:jz).can_administer_card?(logo_card)
    assert_not users(:jz).can_administer_card?(text_card)

    # Creator cannot administer other people's cards
    assert_not users(:david).can_administer_card?(text_card)
  end
end
