require "test_helper"

class BucketTest < ActiveSupport::TestCase
  test "revising access" do
    buckets(:writebook).update! all_access: false

    buckets(:writebook).accesses.revise granted: users(:david, :jz), revoked: users(:kevin)
    assert_equal users(:david, :jz), buckets(:writebook).users

    buckets(:writebook).accesses.grant_to users(:kevin)
    assert_includes buckets(:writebook).users.reload, users(:kevin)

    buckets(:writebook).accesses.revoke_from users(:kevin)
    assert_not_includes buckets(:writebook).users.reload, users(:kevin)
  end

  test "grants access to everyone after creation" do
    bucket = Current.set(session: sessions(:david)) do
      accounts("37s").buckets.create! name: "New bucket", all_access: true
    end
    assert_equal accounts("37s").users, bucket.users
  end

  test "grants access to everyone after update" do
    bucket = Current.set(session: sessions(:david)) do
      accounts("37s").buckets.create! name: "New bucket"
    end
    assert_equal [ users(:david) ], bucket.users

    bucket.update! all_access: true
    assert_equal accounts("37s").users, bucket.users.reload
  end
end
