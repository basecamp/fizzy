require "test_helper"

class Board::PublishableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "published scope" do
    boards(:writebook).publish
    assert_includes Board.published, boards(:writebook)
    assert_not_includes Board.published, boards(:private)
  end

  test "published?" do
    assert_not boards(:writebook).published?
    boards(:writebook).publish
    assert boards(:writebook).published?
  end

  test "publish and unpublish" do
    assert_not boards(:writebook).published?

    assert_difference -> { Board::Publication.count }, +1 do
      boards(:writebook).publish
    end

    assert boards(:writebook).published?

    assert_difference -> { Board::Publication.count }, -1 do
      boards(:writebook).unpublish
    end

    assert_not boards(:writebook).reload.published?
  end

  test "find board by publication key" do
    boards(:writebook).publish
    assert_equal boards(:writebook), Board.find_by_published_key(boards(:writebook).publication.key)

    assert_raise ActiveRecord::RecordNotFound do
      Board.find_by_published_key("invalid")
    end
  end

  test "publish doesn't create duplicate publications" do
    boards(:writebook).publish
    original_publication = boards(:writebook).publication

    assert_no_difference -> { Board::Publication.count } do
      boards(:writebook).publish
    end

    assert_equal original_publication, boards(:writebook).reload.publication
  end
end
