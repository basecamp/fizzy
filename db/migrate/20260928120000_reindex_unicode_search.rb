class ReindexUnicodeSearch < ActiveRecord::Migration[8.2]
  def up
    # Rebuild from source records: MySQL's previous tokenizer discarded Unicode,
    # and SQLite's existing CJK words need character boundaries in the FTS index.
    Card.includes(:rich_text_description).find_each(&:reindex)
    Comment.includes(:rich_text_body, :card).find_each(&:reindex)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restore the previous application version and run search:reindex"
  end
end
