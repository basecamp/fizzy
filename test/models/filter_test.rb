require "test_helper"

class FilterTest < ActiveSupport::TestCase
  test "cards" do
    Current.set session: sessions(:david) do
      @new_collection = accounts("37s").collections.create! name: "Inaccessible Collection"
      @new_card = @new_collection.cards.create!
      @new_card.update!(stage: workflow_stages(:qa_triage))

      cards(:layout).capture Comment.new(body: "I hate haggis")
      cards(:logo).capture Comment.new(body: "I love haggis")
      cards(:logo).update(stage: workflow_stages(:qa_triage))
    end

    assert_not_includes users(:kevin).filters.new.cards, @new_card

    filter = users(:david).filters.new indexed_by: "most_discussed", assignee_ids: [ users(:jz).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ cards(:layout) ], filter.cards

    filter = users(:david).filters.new creator_ids: [ users(:david).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ cards(:layout) ], filter.cards

    filter = users(:david).filters.new stage_ids: [ workflow_stages(:qa_triage).id ]
    assert_equal [ cards(:logo), @new_card ], filter.cards

    filter = users(:david).filters.new assignment_status: "unassigned", collection_ids: [ @new_collection.id ]
    assert_equal [ @new_card ], filter.cards

    filter = users(:david).filters.new terms: [ "haggis" ]
    assert_equal cards(:logo, :layout).sort, filter.cards.sort

    filter = users(:david).filters.new terms: [ "haggis", "love" ]
    assert_equal [ cards(:logo) ], filter.cards

    filter = users(:david).filters.new indexed_by: "closed"
    assert_equal [ cards(:shipping) ], filter.cards
  end

  test "can't see cards in collections that aren't accessible" do
    collections(:writebook).update! all_access: false
    collections(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(collection_ids: [ collections(:writebook).id ]).cards
  end

  test "remembering equivalent filters" do
    assert_difference "Filter.count", +1 do
      filter = users(:david).filters.remember(indexed_by: "most_active", assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])

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
    filter = users(:david).filters.new indexed_by: "most_active", tag_ids: "", assignee_ids: [ users(:jz).id ], collection_ids: [ collections(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id ], collection_ids: [ collections(:writebook).id ] }
    assert_equal expected, filter.as_params
  end

  test "cacheability" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(collection_ids: [ collections(:writebook).id ]).cacheable?
  end

  test "terms" do
    assert_equal [], users(:david).filters.new.terms
    assert_equal [ "haggis" ], users(:david).filters.new(terms: [ "haggis" ]).terms
  end

  test "resource removal" do
    filter = users(:david).filters.create! tag_ids: [ tags(:mobile).id ], collection_ids: [ collections(:writebook).id ]

    assert_includes filter.as_params[:tag_ids], tags(:mobile).id
    assert_includes filter.tags, tags(:mobile)
    assert_includes filter.as_params[:collection_ids], collections(:writebook).id
    assert_includes filter.collections, collections(:writebook)

    assert_changes "filter.reload.updated_at" do
      tags(:mobile).destroy!
    end
    assert_nil filter.reload.as_params[:tag_ids]

    assert_changes "Filter.exists?(filter.id)" do
      collections(:writebook).destroy!
    end
  end

  test "duplicate filters are removed after a resource is destroyed" do
    users(:david).filters.create! tag_ids: [ tags(:mobile).id ], collection_ids: [ collections(:writebook).id ]
    users(:david).filters.create! tag_ids: [ tags(:mobile).id, tags(:web).id ], collection_ids: [ collections(:writebook).id ]

    assert_difference "Filter.count", -1 do
      tags(:web).destroy!
    end
  end

  test "summary" do
    assert_equal "Most discussed, tagged #mobile, and assigned to JZ ", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(stages: workflow_stages(:qa_triage, :qa_in_progress))
    assert_equal "Most discussed, tagged #mobile, assigned to JZ, and staged in Triage or In progress ", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(stages: [], assignees: [], tags: [], collections: [ collections(:writebook) ])
    assert_equal "Most discussed in Writebook", filters(:jz_assignments).summary

    filters(:jz_assignments).update!(indexed_by: "stalled")
    assert_equal "Stalled in Writebook", filters(:jz_assignments).summary
  end

  test "params without a key-value pair" do
    filter = users(:david).filters.new indexed_by: "most_discussed", assignee_ids: [ users(:jz).id, users(:kevin).id ]

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:kevin).id ] }
    assert_equal expected, filter.as_params_without(:assignee_ids, users(:jz).id).to_h

    expected = { assignee_ids: [ users(:jz).id, users(:kevin).id ] }
    assert_equal expected, filter.as_params_without(:indexed_by, "most_discussed").to_h

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:jz).id, users(:kevin).id ] }
    assert_equal expected, filter.as_params_without(:indexed_by, "most_active").to_h

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:jz).id, users(:kevin).id ] }
    assert_equal expected, filter.as_params_without(:assignee_ids, users(:david).id).to_h
  end

  test "get a clone with some changed params" do
    seed_filter = users(:david).filters.new indexed_by: "active", terms: [ "haggis" ]
    filter = seed_filter.with(indexed_by: "closed")

    assert filter.indexed_by.closed?
    assert_equal [ "haggis" ], filter.terms
  end
end
