class ChangeSearchFtsTokenizerToUnicode61 < ActiveRecord::Migration[8.2]
  def up
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS search_records_fts"
    execute <<~SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='unicode61'
      )
    SQL

    reindex_fts_records
  end

  def down
    return unless connection.adapter_name == "SQLite"

    execute "DROP TABLE IF EXISTS search_records_fts"
    execute <<~SQL
      CREATE VIRTUAL TABLE search_records_fts USING fts5(
        title,
        content,
        tokenize='porter'
      )
    SQL

    # Insert original (unstemmed) text — porter tokenizer handles stemming itself
    connection.select_all("SELECT id, title, content FROM search_records").each do |row|
      connection.execute(
        "INSERT INTO search_records_fts(rowid, title, content) VALUES (#{connection.quote(row['id'])}, #{connection.quote(row['title'])}, #{connection.quote(row['content'])})"
      )
    end
  end

  private
    def reindex_fts_records
      connection.select_all("SELECT id, title, content FROM search_records").each do |row|
        stemmed_title = Search::Stemmer.stem(row["title"])
        stemmed_content = Search::Stemmer.stem(row["content"])

        connection.execute(
          "INSERT INTO search_records_fts(rowid, title, content) VALUES (#{connection.quote(row['id'])}, #{connection.quote(stemmed_title)}, #{connection.quote(stemmed_content)})"
        )
      end
    end
end
