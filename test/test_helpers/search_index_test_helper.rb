module SearchIndexTestHelper
  def search_index
    ActiveSearch.index(:searchable)
  end

  # MySQL picks one of sixteen tables from the routing value; SQLite has only the one.
  def search_shard_for(account_id)
    search_index.store.send(:model_for, search_index, routing: account_id)
  end

  # SQLite keeps text fields in the FTS table, so stored title and content are MySQL only.
  def sharded_search?
    search_index.store.is_a?(ActiveSearch::StoreAdapters::MysqlSharded)
  end

  def search_records_for(account_id)
    search_shard_for(account_id).where(account_id: account_id)
  end

  def find_search_record(account_id, type:, id:)
    search_records_for(account_id).find_by(searchable_type: type, searchable_id: id)
  end

  # MySQL stems into the record row, SQLite writes verbatim to the FTS table, so only
  # the length of the two answers is comparable.
  def indexed_content_for(account_id, type:, id:)
    record = find_search_record(account_id, type: type, id: id)
    model = search_shard_for(account_id)

    if sharded_search?
      record.content
    else
      rowid = model.where(id: record.id).pick(:rowid)
      model.connection.select_value("SELECT content FROM #{model.table_name}_fts WHERE rowid = #{rowid}")
    end
  end

  def search_record_exists?(account_id, type:, id:)
    search_records_for(account_id).exists?(searchable_type: type, searchable_id: id)
  end

  def clear_search_records
    Account.find_each { |account| search_index.remove_by_filter(account_id: account.id) }
  end
end
