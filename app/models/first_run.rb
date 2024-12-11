class FirstRun
  # Yields the created User, executed in the context of a tenanted connection.
  # Returns the created Tenant.
  def self.create!(tenant_attributes, user_attributes)
    Tenant.create!(tenant_attributes).tap do |tenant|
      tenant.while_tenanted do
        account = Account.create!(name: "Fizzy")
        user = account.users.create!(user_attributes)
        yield user
      end
    end
  end
end
