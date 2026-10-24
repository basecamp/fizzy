require "test_helper"

class DatabaseAdapterTest < ActiveSupport::TestCase
  unless Fizzy.db_adapter.sqlite?
    test "MySQL connects with mysql2" do
      assert_equal "Mysql2", connection.adapter_name
    end

    test "MySQL connects in utf8mb4" do
      assert_equal "utf8mb4", connection.select_value("SELECT @@character_set_connection")
      assert_equal "🗂️", connection.select_value("SELECT #{connection.quote("🗂️")}")
    end

    test "MySQL reads binary(16) columns as UUIDs" do
      assert_equal :uuid, Card.columns_hash["id"].type
    end
  end

  private
    def connection
      ActiveRecord::Base.connection
    end
end
