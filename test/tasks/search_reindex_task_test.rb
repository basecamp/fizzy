require "test_helper"
require "rake"

class SearchReindexTaskTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("search:reindex")
    Rake::Task["search:reindex"].reenable
  end

  test "reindex removes rows whose account no longer exists and keeps live rows" do
    card = @board.cards.create!(title: "Orphan probe", creator: @user, status: "published")
    assert search_record_exists?(@account.id, type: "Card", id: card.id)

    orphan_account_id, orphan_card_id = SecureRandom.uuid, SecureRandom.uuid
    assert_nil Account.find_by(id: orphan_account_id)
    row = find_search_record(@account.id, type: "Card", id: card.id).attributes.except("id")
      .merge("account_id" => orphan_account_id, "card_id" => orphan_card_id, "searchable_id" => orphan_card_id)
    row["id"] = SecureRandom.uuid if sharded_search?
    search_shard_for(orphan_account_id).insert!(row)
    assert search_record_exists?(orphan_account_id, type: "Card", id: orphan_card_id), "the orphan must exist before the task, or its removal proves nothing"

    capture_io { Rake::Task["search:reindex"].invoke }

    assert_not search_record_exists?(orphan_account_id, type: "Card", id: orphan_card_id)
    assert search_record_exists?(@account.id, type: "Card", id: card.id)
  end
end
