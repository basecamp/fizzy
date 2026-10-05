require "test_helper"

class Board::ArchivableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "archived and active scopes" do
    boards(:writebook).archive

    assert_includes Board.archived, boards(:writebook)
    assert_not_includes Board.archived, boards(:private)

    assert_includes Board.active, boards(:private)
    assert_not_includes Board.active, boards(:writebook)
  end

  test "archive and unarchive" do
    assert_not boards(:writebook).archived?

    assert_difference -> { Board::Archival.count }, +1 do
      boards(:writebook).archive
    end

    assert boards(:writebook).archived?
    assert_equal users(:david), boards(:writebook).archived_by
    assert_not_nil boards(:writebook).archived_at

    assert_difference -> { Board::Archival.count }, -1 do
      boards(:writebook).unarchive
    end

    assert_not boards(:writebook).reload.archived?
  end

  test "archive doesn't create duplicate archivals" do
    boards(:writebook).archive

    assert_no_difference -> { Board::Archival.count } do
      boards(:writebook).archive
    end
  end

  test "touch board when archived and unarchived" do
    assert_changes -> { boards(:writebook).reload.updated_at } do
      boards(:writebook).archive
    end

    assert_changes -> { boards(:writebook).reload.updated_at } do
      boards(:writebook).unarchive
    end
  end

  test "destroying the board destroys its archival" do
    boards(:writebook).archive

    assert_difference -> { Board::Archival.count }, -1 do
      boards(:writebook).destroy
    end
  end

  test "archived boards are skipped when auto-postponing" do
    boards(:writebook).archive
    cards(:logo).update_column :last_active_at, 1.year.ago

    Card.auto_postpone_all_due

    assert_not cards(:logo).reload.postponed?
  end

  test "cards on archived boards are left out of filters unless the board is selected" do
    boards(:writebook).archive

    assert_not_includes users(:david).filters.new.cards, cards(:logo)
    assert_includes users(:david).filters.new(board_ids: [ boards(:writebook).id ]).cards, cards(:logo)
  end
end
