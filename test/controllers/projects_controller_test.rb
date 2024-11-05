require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_project_url
    assert_response :success
  end

  test "create" do
    assert_difference -> { Bucket.projects.count }, +1 do
      post projects_url, params: { project: { name: "Remodel Punch List" } }
    end

    bucket = Bucket.last
    assert_redirected_to bubbles_url(bucket_ids: bucket)
    assert_includes bucket.users, users(:kevin)
    assert_equal "Remodel Punch List", bucket.title
  end

  test "edit" do
    get edit_project_url(buckets(:writebook))
    assert_response :success
  end

  test "update" do
    patch project_url(buckets(:writebook)), params: { project: { name: "Writebook bugs" }, user_ids: users(:david, :jz).pluck(:id) }

    assert_redirected_to bubbles_url(bucket_ids: buckets(:writebook))
    assert_equal "Writebook bugs", buckets(:writebook).title
    assert_equal users(:david, :jz), buckets(:writebook).users
  end
end
