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
  email_address = "david@37signals.com"
  identity = Identity.find_or_create_by!(email_address: email_address)
  membership = identity.memberships.find_or_create_by!(tenant: tenant_id)

  ApplicationRecord.destroy_tenant tenant_id
  ApplicationRecord.create_tenant(tenant_id) do
    account = Account.create_with_admin_user(
      account: {
        external_account_id: tenant_id,
        name: signal_account_name
      },
      owner: {
        name: "David Heinemeier Hansson",
        membership: membership
      }
    )
  end

  ApplicationRecord.current_tenant = tenant_id
end

def find_or_create_user(full_name, email_address)
  if user = Identity.find_by(email_address: email_address)&.memberships&.find_by(tenant: ApplicationRecord.current_tenant)&.user
    user
  else
    identity = Identity.find_or_create_by!(email_address: email_address)
    membership = identity.memberships.find_or_create_by!(tenant: ApplicationRecord.current_tenant)

    user = User.create! \
      name: full_name,
      membership: membership

    user
  end
end

def login_as(user)
  Current.session = user.identity.sessions.create
end

def create_board(name, creator: Current.user, all_access: true, access_to: [])
  Board.create!(name:, creator:, all_access:).tap { it.accesses.grant_to(access_to) }
end

def create_card(title, board:, description: nil, status: :published, creator: Current.user)
  board.cards.create!(title:, description:, creator:, status:)
end

# Seed accounts
seed_account "cleanslate"
seed_account "37signals"
seed_account "honcho"
