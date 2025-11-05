namespace :seed do
  desc "Seed customer data for a specific account (e.g: rails seed:customer ARTENANT=1234)"
  task :customer, [ :tenant_id ] => "db:tenant" do |t, args|
    raise "Please provide a tenant ID: rails seed:customer ARTENANT=1234" unless ApplicationRecord.current_tenant

    account = Account.sole
    Account::Seeder.new(account, User.active.first).seed!

    puts "✓ Seeded account #{account.name} (tenant: #{account.id})"
  end
end
