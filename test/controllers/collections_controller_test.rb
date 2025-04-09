require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_collection_url
    assert_response :success
  end

  test "create" do
    assert_difference -> { Collection.count }, +1 do
      post collections_url, params: { collection: { name: "Remodel Punch List" } }
    end

    collection = Collection.last
    assert_redirected_to cards_path(collection_ids: [ collection ])
    assert_includes collection.users, users(:kevin)
    assert_equal "Remodel Punch List", collection.name
  end

  test "edit" do
    get edit_collection_url(collections(:writebook))
    assert_response :success
  end

  test "update" do
    patch collection_url(collections(:writebook)), params: {
      collection: {
        name: "Writebook bugs",
        all_access: false
      },
      user_ids: users(:david, :jz).pluck(:id)
    }

    assert_redirected_to cards_path(collection_ids: [ collections(:writebook) ])
    assert_equal "Writebook bugs", collections(:writebook).reload.name
    assert_equal users(:david, :jz).sort, collections(:writebook).users.sort
    assert_not collections(:writebook).all_access?
  end

  test "update all access" do
    collection = Current.set(session: sessions(:kevin)) do
      accounts("37s").collections.create! name: "New collection", all_access: false
    end
    assert_equal [ users(:kevin) ], collection.users

    patch collection_url(collection), params: { collection: { name: "Bugs", all_access: true } }

    assert_redirected_to cards_path(collection_ids: [ collection ])
    assert collection.reload.all_access?
    assert_equal accounts("37s").users, collection.users
  end

  test "destroy" do
    assert_difference -> { Collection.count }, -1 do
      delete collection_url(collections(:writebook))
      assert_redirected_to root_url
    end
  end
end
