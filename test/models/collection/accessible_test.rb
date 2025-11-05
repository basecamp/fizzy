require "test_helper"

class Collection::AccessibleTest < ActiveSupport::TestCase
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
      Collection.create! name: "New collection", all_access: true
    end
    assert_equal User.active.sort, collection.users.sort
  end

  test "grants access to everyone after update" do
    collection = Current.set(session: sessions(:david)) do
      Collection.create! name: "New collection"
    end
    assert_equal [ users(:david) ], collection.users

    collection.update! all_access: true
    assert_equal User.active.sort, collection.users.reload.sort
  end

  test "collection watchers" do
    collections(:writebook).access_for(users(:kevin)).watching!
    assert_includes collections(:writebook).watchers, users(:kevin)

    collections(:writebook).access_for(users(:kevin)).access_only!
    assert_not_includes collections(:writebook).reload.watchers, users(:kevin)
  end
end
