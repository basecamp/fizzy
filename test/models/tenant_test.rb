require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "attr slug is validated as unique" do
    Tenant.create!(slug: "foo")

    assert_raises(ActiveRecord::RecordInvalid) do
      Tenant.create!(slug: "foo")
    end

    assert_not(Tenant.new(slug: "foo").valid?)
  end

  test "attr dbname must be unique in the database" do
    Tenant.create!(slug: "foo", dbname: "c0ffee")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Tenant.create!(slug: "bar", dbname: "c0ffee")
    end
  end

  test "attr dbname is generated on creation" do
    tenant = Tenant.new(slug: "foo")

    assert_nil tenant.dbname

    tenant.save!

    assert_not_nil tenant.dbname
  end

  test "#while_tenanted yields the block with the tenant's connection" do
    tenant = Tenant.create!(slug: "foo")

    return_value = tenant.while_tenanted do |t|
      assert_equal tenant, t
      assert_equal tenant.dbname.to_sym, ApplicationRecord.current_shard

      :xxx
    end

    assert_equal :xxx, return_value
  end

  test ".while_untenanted yields the block with a placeholder connection" do
    return_value = Tenant.while_untenanted do
      assert_equal :nonexistent, ApplicationRecord.current_shard
      assert ApplicationRecord.current_preventing_writes

      Tenant.create!(slug: "foo").while_tenanted do |tenant|
        inner_block_called = true

        assert_equal tenant.dbname.to_sym, ApplicationRecord.current_shard
        assert_not ApplicationRecord.current_preventing_writes

        :xxx
      end
    end

    assert_equal :xxx, return_value
  end
end
