require "test_helper"

class FilterTest < ActiveSupport::TestCase
  test "remembering" do
    assert_difference "users(:david).filters.count", +1 do
      filter = users(:david).filters.remember(indexed_by: "most_active", assignment_status: "unassigned", tag_ids: [ tags(:mobile).id.to_s ])

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.remember(assignment_status: "unassigned", tag_ids: [ tags(:mobile).id.to_s ])
      end
    end
  end

  test "remembering filters that are essentially the same" do
    filter = users(:david).filters.remember(bubble_limit: 3, assignment_status: "unassigned", tag_ids: [ tags(:mobile).id.to_s ])

    assert_changes "filter.reload.updated_at" do
      assert_equal filter, users(:david).filters.remember(bubble_limit: 5, assignment_status: "unassigned", tag_ids: [ tags(:mobile).id.to_s ])
    end
  end

  test "bubbles" do
    Current.set session: sessions(:david) do
      @new_bucket = accounts("37s").buckets.create! name: "Inaccessible Bucket"
      @new_bubble = @new_bucket.bubbles.create!

      bubbles(:layout).capture Comment.new(body: "I hate haggis")
      bubbles(:logo).capture Comment.new(body: "I love haggis")
    end

    assert_not_includes users(:kevin).filters.new.bubbles, @new_bubble

    filter = users(:david).filters.new indexed_by: "most_discussed", assignee_ids: [ users(:jz).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ bubbles(:layout) ], filter.bubbles

    filter = users(:david).filters.new assigner_ids: [ users(:david).id ], tag_ids: [ tags(:mobile).id ]
    assert_equal [ bubbles(:layout) ], filter.bubbles

    filter = users(:david).filters.new assignment_status: "unassigned", bucket_ids: [ @new_bucket.id ]
    assert_equal [ @new_bubble ], filter.bubbles

    filter = users(:david).filters.new terms: [ "haggis" ]
    assert_equal bubbles(:logo, :layout), filter.bubbles

    filter = users(:david).filters.new terms: [ "haggis", "love" ]
    assert_equal [ bubbles(:logo) ], filter.bubbles

    filter = users(:david).filters.new indexed_by: "popped"
    assert_equal [ bubbles(:shipping) ], filter.bubbles
  end

  test "can't see bubbles in buckets that aren't accessible" do
    buckets(:writebook).update! all_access: false
    buckets(:writebook).accesses.revoke_from users(:david)

    assert_empty users(:david).filters.new(bucket_ids: [ buckets(:writebook).id ]).bubbles
  end

  test "turning into query" do
    filter = users(:david).filters.new indexed_by: "most_active", tag_ids: "", assignee_ids: [ users(:jz).id ], bucket_ids: [ buckets(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id.to_s ], bucket_ids: [ buckets(:writebook).id.to_s ] }
    assert_equal expected, filter.as_params
  end

  test "cacheable" do
    assert_not filters(:jz_assignments).cacheable?
    assert users(:david).filters.create!(bucket_ids: [ buckets(:writebook).id ]).cacheable?
  end

  test "default fields" do
    assert_equal "most_active", users(:david).filters.new.indexed_by
  end

  test "indexed by" do
    assert_predicate users(:david).filters.new(indexed_by: "most_discussed").indexed_by, :most_discussed?
  end

  test "assignments" do
    assert_predicate users(:david).filters.new(assignment_status: "unassigned").assignment_status, :unassigned?
  end

  test "terms" do
    assert_empty users(:david).filters.new.terms
    assert_includes users(:david).filters.new(terms: [ "haggis" ]).terms, "haggis"
  end

  test "resource removal" do
    filter = users(:david).filters.create! tag_ids: [ tags(:mobile).id ], bucket_ids: [ buckets(:writebook).id ]

    assert_includes filter.as_params[:tag_ids], tags(:mobile).id.to_s
    assert_includes filter.tags, tags(:mobile)
    assert_includes filter.as_params[:bucket_ids], buckets(:writebook).id.to_s
    assert_includes filter.buckets, buckets(:writebook)

    assert_changes "filter.reload.updated_at" do
      tags(:mobile).destroy!
    end
    assert_nil filter.reload.as_params[:tag_ids]

    assert_changes "Filter.exists?(filter.id)" do
      buckets(:writebook).destroy!
    end
  end

  test "duplicate filters are removed after a resource is destroyed" do
    users(:david).filters.create! tag_ids: [ tags(:mobile).id ], bucket_ids: [ buckets(:writebook).id ]
    users(:david).filters.create! tag_ids: [ tags(:mobile).id, tags(:web).id ], bucket_ids: [ buckets(:writebook).id ]

    assert_difference "Filter.count", -1 do
      tags(:web).destroy!
    end
  end

  test "summary" do
    assert_equal "Most discussed, tagged #Mobile, and assigned to JZ in all projects", filters(:jz_assignments).summary
  end

  test "plain summary" do
    assert_equal "Most discussed, tagged #Mobile, and assigned to JZ in all projects", filters(:jz_assignments).plain_summary
  end

  test "params without a key-value pair" do
    filter = users(:david).filters.new indexed_by: "most_discussed", assignee_ids: [ users(:jz).id, users(:kevin).id ]

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:kevin).id.to_s ] }
    assert_equal expected, filter.as_params_without(:assignee_ids, users(:jz).id.to_s).to_h

    expected = { assignee_ids: [ users(:jz).id.to_s, users(:kevin).id.to_s ] }
    assert_equal expected, filter.as_params_without(:indexed_by, "most_discussed").to_h

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:jz).id.to_s, users(:kevin).id.to_s ] }
    assert_equal expected, filter.as_params_without(:indexed_by, "most_active").to_h

    expected = { indexed_by: "most_discussed", assignee_ids: [ users(:jz).id.to_s, users(:kevin).id.to_s ] }
    assert_equal expected, filter.as_params_without(:assignee_ids, users(:david).id.to_s).to_h
  end
end
