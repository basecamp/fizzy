class Search::Record < ApplicationRecord
  if connection.adapter_name == "Mysql2"
    self.abstract_class = true  # MySQL uses sharded tables; shard models set their own table_name
  else
    self.table_name = "search_records"
  end
end
