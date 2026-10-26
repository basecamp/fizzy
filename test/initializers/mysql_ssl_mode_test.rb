require "test_helper"

class MysqlSslModeTest < ActiveSupport::TestCase
  test "verify_ca is refused" do
    %w[ verify_ca VERIFY_CA ].each do |mode|
      with_mysql_ssl_mode(mode) do
        error = assert_raises(RuntimeError) { load_initializer }
        assert_match "verify_identity", error.message
      end
    end
  end

  test "other modes are allowed" do
    [ nil, "disabled", "required", "verify_identity" ].each do |mode|
      with_mysql_ssl_mode(mode) { assert_nothing_raised { load_initializer } }
    end
  end

  private
    def with_mysql_ssl_mode(mode)
      original = ENV["MYSQL_SSL_MODE"]
      ENV["MYSQL_SSL_MODE"] = mode
      yield
    ensure
      ENV["MYSQL_SSL_MODE"] = original
    end

    def load_initializer
      load Rails.root.join("config/initializers/mysql_ssl_mode.rb").to_s
    end
end
