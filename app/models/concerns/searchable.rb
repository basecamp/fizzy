module Searchable
  extend ActiveSupport::Concern

  def self.search_index_table_name(account_id)
    "search_index_#{Zlib.crc32(account_id) % 16}"
  end

  included do
    after_create_commit :create_in_search_index
    after_update_commit :update_in_search_index
    after_destroy_commit :remove_from_search_index
  end

  def reindex
    update_in_search_index
  end

  private
    def create_in_search_index
      table_name = Searchable.search_index_table_name(account_id)
      uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)

      self.class.connection.execute self.class.sanitize_sql([
        "INSERT INTO #{table_name} (id, searchable_type, searchable_id, card_id, board_id, title, content, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        uuid_type.serialize(ActiveRecord::Type::Uuid.generate),
        self.class.name,
        uuid_type.serialize(id),
        uuid_type.serialize(search_card_id),
        uuid_type.serialize(search_board_id),
        search_title,
        search_content,
        created_at
      ])
    end

    def update_in_search_index
      table_name = Searchable.search_index_table_name(account_id)
      uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)

      result = self.class.connection.execute(self.class.sanitize_sql([
        "UPDATE #{table_name} SET card_id = ?, board_id = ?, title = ?, content = ?, created_at = ? WHERE searchable_type = ? AND searchable_id = ?",
        uuid_type.serialize(search_card_id),
        uuid_type.serialize(search_board_id),
        search_title,
        search_content,
        created_at,
        self.class.name,
        uuid_type.serialize(id)
      ]))

      create_in_search_index if result.affected_rows == 0
    end

    def remove_from_search_index
      table_name = Searchable.search_index_table_name(account_id)
      uuid_type = ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)

      self.class.connection.execute self.class.sanitize_sql([
        "DELETE FROM #{table_name} WHERE searchable_type = ? AND searchable_id = ?",
        self.class.name,
        uuid_type.serialize(id)
      ])
    end

  # Models must implement these methods:
  # - search_title: returns title string or nil
  # - search_content: returns content string
  # - search_card_id: returns the card id (self.id for cards, card_id for comments)
  # - search_board_id: returns the board id
end
