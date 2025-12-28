# rbs_inline: enabled

class Search::Record::SQLite::Fts < ApplicationRecord
  self.table_name = "search_records_fts"
  self.primary_key = "rowid"

  # FTS5 virtual table columns
  attribute :rowid, :integer
  attribute :title, :string
  attribute :content, :string

  # FTS5 virtual tables don't expose rowid in the schema by default
  # We need to explicitly select it when loading records
  scope :with_rowid, -> { select(:rowid, :title, :content) }

  def self.upsert(rowid, title, content)
    connection.exec_query(
      "INSERT OR REPLACE INTO search_records_fts(rowid, title, content) VALUES (?, ?, ?)",
      "Search::Record::SQLite::Fts Upsert",
      [ rowid, title, content ]
    )
  end
end
