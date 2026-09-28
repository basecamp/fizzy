# Registration resolves the adapter names in config/search.yml.
ActiveSearch.register_adapter :mysql_sharded, "ActiveSearch::StoreAdapters::MysqlSharded"

ActiveSearch.register_adapter :sqlite_cjk, "ActiveSearch::StoreAdapters::SQLiteCjk"

ActiveSearch.define_index(:searchable, polymorphic: true, route_by: :account_id,
                          document_class: "Search::Record") do
  text :title
  text :content
  string :account_id
  string :board_id
  string :card_id
  string :searchable_type
  string :searchable_id
  datetime :created_at
end
