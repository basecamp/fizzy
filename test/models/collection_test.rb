require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "revising access" do
    collections(:writebook).update! all_access: false

    collections(:writebook).accesses.revise granted: users(:david, :jz), revoked: users(:kevin)
    assert_equal users(:david, :jz), collections(:writebook).users

    collections(:writebook).accesses.grant_to users(:kevin)
    assert_includes collections(:writebook).users.reload, users(:kevin)

    collections(:writebook).accesses.revoke_from users(:kevin)
    assert_not_includes collections(:writebook).users.reload, users(:kevin)
  end

  test "grants access to everyone after creation" do
    collection = Current.set(session: sessions(:david)) do
      accounts("37s").collections.create! name: "New collection", all_access: true
    end
    assert_equal accounts("37s").users, collection.users
  end

  test "grants access to everyone after update" do
    collection = Current.set(session: sessions(:david)) do
      accounts("37s").collections.create! name: "New collection"
    end
    assert_equal [ users(:david) ], collection.users

    collection.update! all_access: true
    assert_equal accounts("37s").users, collection.users.reload
  end
end
