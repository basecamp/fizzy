require "test_helper"

class LandingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "redirects to the timeline when many collections" do
    get landing_path
    assert_redirected_to events_path
  end

  test "redirects to the timeline when no collections" do
    Collection.destroy_all
    get landing_path
    assert_redirected_to events_path
  end

  test "redirects to collections when only one collection" do
    sole_collection, *collections_to_delete = users(:kevin).collections.to_a
    collections_to_delete.each(&:destroy)

    get landing_path
    assert_redirected_to collection_path(sole_collection)
  end
end
