require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_bucket_url
    assert_response :success
  end

  test "create" do
    assert_difference -> { Bucket.count }, +1 do
      post buckets_url, params: { bucket: { name: "Remodel Punch List" } }
    end

    bucket = Bucket.last
    assert_redirected_to bubbles_path(bucket_ids: [ bucket ])
    assert_includes bucket.users, users(:kevin)
    assert_equal "Remodel Punch List", bucket.name
  end

  test "edit" do
    get edit_bucket_url(buckets(:writebook))
    assert_response :success
  end

  test "update" do
    patch bucket_url(buckets(:writebook)), params: {
      bucket: {
        name: "Writebook bugs",
        all_access: false
      },
      user_ids: users(:david, :jz).pluck(:id)
    }

    assert_redirected_to bubbles_path(bucket_ids: [ buckets(:writebook) ])
    assert_equal "Writebook bugs", buckets(:writebook).reload.name
    assert_equal users(:david, :jz).sort, buckets(:writebook).users.sort
    assert_not buckets(:writebook).all_access?
  end

  test "update all access" do
    bucket = Current.set(session: sessions(:kevin)) do
      accounts("37s").buckets.create! name: "New bucket", all_access: false
    end
    assert_equal [ users(:kevin) ], bucket.users

    patch bucket_url(bucket), params: { bucket: { name: "Bugs", all_access: true } }

    assert_redirected_to bubbles_path(bucket_ids: [ bucket ])
    assert bucket.reload.all_access?
    assert_equal accounts("37s").users, bucket.users
  end

  test "destroy" do
    assert_difference -> { Bucket.count }, -1 do
      delete bucket_url(buckets(:writebook))
      assert_redirected_to root_url
    end
  end
end
