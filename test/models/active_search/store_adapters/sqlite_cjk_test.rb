require "test_helper"
require_relative "../../../../db/migrate/20260928120000_reindex_unicode_search"

class ActiveSearch::StoreAdapters::SQLiteCjkTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    skip "SQLite-specific indexing" if sharded_search?
  end

  test "CJK search requires characters in order and supports comments and mixed scripts" do
    matching = @board.cards.create!(title: "Fizzy中文测试", description: "原始中文描述", status: "published", creator: @user)
    @board.cards.create!(title: "文中", status: "published", creator: @user)
    @board.cards.create!(title: "中间文", status: "published", creator: @user)
    comment = matching.comments.create!(body: "日本語の説明", creator: @user)

    assert_equal [ matching ], @user.search("中文").results.to_a
    assert_equal [ matching ], @user.search("Fizzy中文").results.to_a
    assert_equal [ comment ], @user.search("日本語").results.to_a
    assert_equal [ matching ], @user.search('"中文测试"').results.to_a
    hit = @user.search("中文").results.to_a.sole.hit
    assert_equal "Fizzy中文测试", hit.fields[:title]
    assert_equal "原始中文描述", hit.fields[:content]
  end

  test "reindex migration makes legacy CJK content searchable" do
    card = @board.cards.create!(title: "历史中文卡片", status: "published", creator: @user)
    record = find_search_record(@account.id, type: "Card", id: card.id)
    model = search_shard_for(@account.id)
    rowid = model.where(id: record.id).pick(:rowid)

    # Write exactly as the upstream adapter did, without CJK token boundaries.
    ActiveSearch::StoreAdapters::Sqlite.new.write_fts_row(model, "#{model.table_name}_fts", rowid,
      [ :title, :content ], { title: card.title, content: "" })
    assert_empty @user.search("中文").results.to_a

    ReindexUnicodeSearch.new.up

    assert_equal [ card ], @user.search("中文").results.to_a
  end
end
