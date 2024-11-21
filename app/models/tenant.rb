class Tenant < MetaRecord
  validates :slug, uniqueness: true

  before_save :ensure_unique_dbname

  class << self
    # during first run tenant creation, there is no current Tenant, but we will need to connect to a
    # new one if we create it. let's bind to a fake readonly shard here, but allow changing shards.
    def while_untenanted
      ApplicationRecord.connected_to(shard: :nonexistent) do
        ApplicationRecord.while_preventing_writes(true) do
          yield
        end
      end
    end
  end

  def while_tenanted
    ApplicationRecord.connected_to(shard: dbname.to_sym) do
      ApplicationRecord.prohibit_shard_swapping(true) do
        yield self
      end
    end
  end

  private
    def ensure_unique_dbname
      return if dbname.present?

      self.dbname = generate_dbname
    end

    def generate_dbname
      SecureRandom.hex(16)
    end
end
