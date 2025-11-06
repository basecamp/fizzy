require "test_helper"

class FilterTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards" do
    Current.set session: sessions(:david) do
      @new_board = Board.create! name: "Inaccessible Board"
      @new_card = @new_board.cards.create!(status: "published")

      cards(:layout).comments.create!(body: "I hate haggis")
      cards(:logo).comments.create!(body: "I love haggis")
    end

    assert_not_includes users(:kevin).filters.new.cards, @new_card

    filter = users(:david).filters.new creator_ids: [ users(:david).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ cards(:layout) ], filter.cards

    filter = users(:david).filters.new assignment_status: "unassigned", board_ids: [ @new_board.id ]
    assert_equal [ @new_card ], filter.cards

    filter = users(:david).filters.new indexed_by: "closed"
    assert_equal [ cards(:shipping) ], filter.cards

    cards(:shipping).postpone
    filter = users(:david).filters.new indexed_by: "not_now"
    assert_includes filter.cards, cards(:shipping)

    filter = users(:david).filters.new card_ids: [ cards(:logo, :layout).collect(&:id) ]
    assert_equal [ cards(:logo), cards(:layout) ], filter.cards
  end

  test "can't see cards in boards that aren't accessible" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(board_ids: [ boards(:writebook).id ]).cards
  end

  test "can't see boards that aren't accessible" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(board_ids: [ boards(:writebook).id ]).boards
  end

  test "remembering equivalent filters" do
    assert_difference "Filter.count", +1 do
      filter = users(:david).filters.remember(sorted_by: "latest", assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.remember(tag_ids: [ tags(:mobile).id ], assignment_status: "unassigned")
      end
    end
  end

  test "remembering equivalent filters for different users" do
    assert_difference "Filter.count", +2 do
      users(:david).filters.remember(assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])
      users(:kevin).filters.remember(assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])
    end
  end

  test "turning into params" do
    filter = users(:david).filters.new sorted_by: "latest", tag_ids: "", assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ] }
    assert_equal expected, filter.as_params
  end

  test "cacheability" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(board_ids: [ boards(:writebook).id ]).cacheable?
  end

  test "terms" do
    assert_equal [], users(:david).filters.new.terms
    assert_equal [ "haggis" ], users(:david).filters.new(terms: [ "haggis" ]).terms
  end

  test "resource removal" do
    filter = users(:david).filters.create! tag_ids: [ tags(:mobile).id ], board_ids: [ boards(:writebook).id ]

    assert_includes filter.as_params[:tag_ids], tags(:mobile).id
    assert_includes filter.tags, tags(:mobile)
    assert_includes filter.as_params[:board_ids], boards(:writebook).id
    assert_includes filter.boards, boards(:writebook)

    assert_changes "filter.reload.updated_at" do
      tags(:mobile).destroy!
    end
    assert_nil Filter.find(filter.id).as_params[:tag_ids]

    Current.set session: sessions(:david) do
      assert_changes "Filter.exists?(filter.id)" do
        boards(:writebook).destroy!
      end
    end
  end

  test "duplicate filters are removed after a resource is destroyed" do
    users(:david).filters.create! tag_ids: [ tags(:mobile).id ], board_ids: [ boards(:writebook).id ]
    users(:david).filters.create! tag_ids: [ tags(:mobile).id, tags(:web).id ], board_ids: [ boards(:writebook).id ]

    assert_difference "Filter.count", -1 do
      tags(:web).destroy!
    end
  end

  test "summary" do
    assert_equal "Newest, #mobile, and assigned to JZ", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(assignees: [], tags: [], boards: [ boards(:writebook) ])
    assert_equal "Newest", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(indexed_by: "stalled", sorted_by: "latest")
    assert_equal "Stalled", filters(:jz_assignments).summary
  end

  test "get a clone with some changed params" do
    seed_filter = users(:david).filters.new indexed_by: "all", terms: [ "haggis" ]
    filter = seed_filter.with(indexed_by: "closed")

    assert filter.indexed_by.closed?
    assert_equal [ "haggis" ], filter.terms
  end

  test "creation window" do
    filter = users(:david).filters.new creation: "this week"

    cards(:logo).update_columns created_at: 2.weeks.ago
    assert_not_includes filter.cards, cards(:logo)

    cards(:logo).update_columns created_at: Time.current
    assert_includes filter.cards, cards(:logo)
  end

  test "closure window" do
    filter = users(:david).filters.new closure: "this week"

    cards(:shipping).closure.update_columns created_at: 2.weeks.ago
    assert_not_includes filter.cards, cards(:shipping)

    cards(:shipping).closure.update_columns created_at: Time.current
    assert_includes filter.cards, cards(:shipping)
  end

  test "completed by" do
    cards(:shipping).closure.update_columns user_id: users(:david).id

    filter = users(:david).filters.new closer_ids: [ users(:david).id ]
    assert_includes filter.cards, cards(:shipping)

    filter = users(:david).filters.new closer_ids: [ users(:jz).id ]
    assert_not_includes filter.cards, cards(:shipping)

    cards(:shipping).closure.update_columns user_id: users(:jz).id

    filter = users(:david).filters.new closer_ids: [ users(:jz).id ]
    assert_includes filter.cards, cards(:shipping)
  end

  test "check if a filter is used" do
    assert users(:david).filters.new(creator_ids: [ users(:david).id ]).used?
    assert_not users(:david).filters.new.used?

    assert users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?
    assert_not users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?(ignore_boards: true)
  end
end
