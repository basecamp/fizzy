#!/usr/bin/env ruby
# Usage: script/create-account "Company Name" "Owner Name" "owner@example.com"

require_relative "../config/environment"

# Parse arguments
if ARGV.size != 3
  puts "Usage: script/create-account <company_name> <owner_name> <owner_email>"
  puts "Example: script/create-account 'Acme Corp' 'John Doe' 'john@acme.com'"
  exit 1
end

company_name, owner_name, owner_email = ARGV

# Create a minimal Current context for the signup
Current.set(
  ip_address: "127.0.0.1",
  user_agent: "create-account script",
  referrer: nil
) do
  puts "Creating account..."
  puts "  Company: #{company_name}"
  puts "  Owner: #{owner_name}"
  puts "  Email: #{owner_email}"
  puts

  # Step 1: Create the account in QueenBee
  queenbee_account_attributes = {
    skip_remote: true,
    product_name: "fizzy",
    name: company_name,
    owner_name: owner_name,
    owner_email: owner_email,
    trial: true,
    subscription: {
      name: "FreeV1",
      price: 0
    },
    remote_request: {
      remote_address: Current.ip_address,
      user_agent: Current.user_agent,
      referrer: Current.referrer
    }
  }

  begin
    queenbee_account = Queenbee::Remote::Account.create!(queenbee_account_attributes)
    puts "✓ Account created in QueenBee"
  rescue => error
    puts "Error creating QueenBee account:"
    puts "  - #{error.message}"
    exit 1
  end

  # Step 2: Create tenant with the QueenBee account ID
  tenant_id = queenbee_account.id.to_s

  begin
    ApplicationRecord.create_tenant(tenant_id) do
      # Create account with admin user
      account = Account.create_with_admin_user(
        account: {
          external_account_id: tenant_id,
          name: company_name
        },
        owner: {
          name: owner_name,
          email_address: owner_email
        }
      )
    end

    puts "✓ Tenant created"
    puts "✓ Account setup completed"
  rescue => error
    # Clean up QueenBee account if tenant creation fails
    queenbee_account&.cancel

    puts "Error setting up tenant:"
    puts "  - #{error.message}"
    exit 1
  end

  # Step 3: Get or create join code
  ApplicationRecord.with_tenant(tenant_id) do
    account = Account.sole
    join_code = account.join_code

    puts "✓ Join code ready"
    puts
    puts "Account created successfully!"
    puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    puts "Tenant: #{tenant_id}"
    puts "Company: #{company_name}"
    puts "Owner: #{owner_name}"
    puts "Email: #{owner_email}"
    puts "Join URL: #{Rails.application.routes.url_helpers.join_url(
      join_code: join_code,
      script_name: "/#{tenant_id}",
      host: Rails.application.config.action_mailer.default_url_options[:host],
      port: Rails.application.config.action_mailer.default_url_options[:port],
      protocol: Rails.env.production? ? 'https' : 'http'
    )}"
  end
end
