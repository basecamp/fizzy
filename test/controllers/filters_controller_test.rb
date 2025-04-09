require "test_helper"

class FiltersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "create" do
    assert_difference "users(:david).filters.count", +1 do
      post filters_url, params: {
        indexed_by: "closed",
        assignment_status: "unassigned",
        tag_ids: [ tags(:mobile).id ],
        assignee_ids: [ users(:jz).id ],
        collection_ids: [ collections(:writebook).id ] }
    end
    assert_redirected_to cards_path(Filter.last.as_params)

    filter = Filter.last
    assert_predicate filter.indexed_by, :closed?
    assert_predicate filter.assignment_status, :unassigned?
    assert_equal [ tags(:mobile) ], filter.tags
    assert_equal [ users(:jz) ], filter.assignees
    assert_equal [ collections(:writebook) ], filter.collections
  end

  test "destroy" do
    assert_difference "users(:david).filters.count", -1 do
      delete filter_url(filters(:jz_assignments))
    end
    assert_redirected_to cards_path(filters(:jz_assignments).as_params)
  end
end
