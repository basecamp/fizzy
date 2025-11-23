module Fizzy
  class << self
    def saas?
      return @saas if defined?(@saas)
      @saas = !!(ENV["SAAS"] || File.exist?(File.expand_path("../../tmp/saas.txt", __dir__)))
    end

    def db_adapter
      @db_adapter ||= DbAdapter.new ENV.fetch("DATABASE_ADAPTER", saas? ? "mysql" : "sqlite")
    end

    def configure_bundle
      if saas?
        ENV["BUNDLE_WITH"] = [ ENV["BUNDLE_WITH"], "saas" ].compact.join(",")
      end
    end
  end

  class DbAdapter
    def initialize(name)
      @name = name.to_s
    end

    def to_s
      @name
    end

    # Not using inquiry so that it works before Rails env loads.
    def sqlite?
      @name == "sqlite"
    end
  end
end
