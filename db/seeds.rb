unless Rails.env.development?
  puts "WARN: Seeding is just for development!"
else
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
    email_address = "david@example.com"
    identity = Identity.find_or_create_by!(email_address: email_address, staff: true)

    unless account = Account.find_by(external_account_id: tenant_id)
      account = Account.create_with_owner(
        account: {
          external_account_id: tenant_id,
          name: signal_account_name
        },
        owner: {
          name: "David Heinemeier Hansson",
          identity: identity
        }
      )
    end
    Current.account = account
  end

  def find_or_create_user(full_name, email_address)
    identity = Identity.find_or_create_by!(email_address: email_address)
    if user = identity.users.find_by(account: Current.account)
      user
    else
      User.create!(name: full_name, identity: identity, account: Current.account, verified_at: Time.current)
    end
  end

  def login_as(user)
    Current.session = user.identity.sessions.create
  end

  def create_board(name, creator: Current.user, all_access: true, access_to: [])
    Board.find_or_create_by!(name:, creator:, all_access:).tap { it.accesses.grant_to(access_to) }
  end

  def create_card(title, board:, description: nil, status: :published, creator: Current.user)
    board.cards.create!(title:, description:, creator:, status:)
  end

  # Seed accounts
  seed_account "cleanslate"
  seed_account "37signals"
  seed_account "honcho"
end
