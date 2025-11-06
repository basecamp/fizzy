require "test_helper"

class User::RoleTest < ActiveSupport::TestCase
  test "can administer others?" do
    assert users(:kevin).can_administer?(users(:jz))

    assert_not users(:kevin).can_administer?(users(:kevin))
    assert_not users(:jz).can_administer?(users(:kevin))
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
