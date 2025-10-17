raise "Seeding is just for development" unless Rails.env.development?

require "active_support/testing/time_helpers"
include ActiveSupport::Testing::TimeHelpers

# Seed DSL
def seed_account(name)
  print "  #{name}…"
  elapsed = Benchmark.realtime { require_relative "seeds/#{name}" }
  puts " #{elapsed.round(2)} sec"
end

def create_tenant(signal_account_name)
  tenant_id = ActiveRecord::FixtureSet.identify signal_account_name

  ApplicationRecord.destroy_tenant tenant_id
  ApplicationRecord.create_tenant(tenant_id) do
    account = Account.create_with_admin_user(
      account: {
        external_account_id: tenant_id,
        name: signal_account_name
      },
      owner: {
        name: "David Heinemeier Hansson",
        email_address: "david@37signals.com",
        password: "secret123456"
      }
    )
    account.setup_basic_template
  end

  ApplicationRecord.current_tenant = tenant_id

  identity = Identity.find_or_create_by!(email_address: User.first.email_address)
  identity.memberships.find_or_create_by!(tenant: tenant_id, account_name: Account.sole.name)
end

def find_or_create_user(full_name, email_address)
  if user = User.find_by(email_address: email_address)
    user
  else
    user = User.create! \
      name: full_name,
      email_address: email_address,
      password: "secret123456"

    identity = Identity.find_or_create_by!(email_address: email_address)
    identity.memberships.find_or_create_by!(tenant: ApplicationRecord.current_tenant, account_name: Account.sole.name)

    user
  end
end

def login_as(user)
  Current.session = user.sessions.create
end

def create_collection(name, creator: Current.user, all_access: true, access_to: [])
  Collection.create!(name:, creator:, all_access:).tap { it.accesses.grant_to(access_to) }
end

def create_card(title, collection:, description: nil, status: :published, creator: Current.user)
  collection.cards.create!(title:, description:, creator:, status:)
end

# Seed accounts
seed_account "cleanslate"
seed_account "37signals"
seed_account "honcho"
