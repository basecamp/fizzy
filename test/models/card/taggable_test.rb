require "test_helper"

class Card::TaggableTest < ActiveSupport::TestCase
  setup do
    @card = cards(:logo)
  end

  test "toggle tag" do
    assert_difference -> { @card.tags.count }, 1 do
      @card.toggle_tag_with "ruby"
    end

    assert_equal "ruby", @card.tags.last.title

    assert_difference -> { @card.tags.count }, -1 do
      @card.toggle_tag_with "ruby"
    end
  end

  test "scope tags by account" do
    assert_difference -> { Tag.count }, 2 do
      cards(:logo).toggle_tag_with "ruby"
      cards(:paycheck).toggle_tag_with "ruby"
    end

    assert_not_equal cards(:logo).tags.last, cards(:paycheck).tags.last
  end

  test "updating just tag_ids touches the card and board" do
    board = @card.board

    travel 1.minute do
      assert_changes -> { @card.reload.updated_at } do
        assert_changes -> { board.reload.updated_at } do
          @card.update!(tag_ids: [ tags(:web).id, tags(:mobile).id ])
        end
      end
    end
  end

  test "updating tag_ids raises when a tag does not exist" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @card.update!(tag_ids: [ "does-not-exist" ])
    end
  end

  test "updating tag_ids raises when the tag belongs to another account" do
    foreign_tag = accounts(:initech).tags.create!(title: "foreign")

    assert_raises(ActiveRecord::RecordNotFound) do
      @card.update!(tag_ids: [ foreign_tag.id ])
    end
  end
end
