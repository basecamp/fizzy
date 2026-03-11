require "csv"

namespace :saas do
  desc "Generate a CSV usage report for all active accounts"
  task usage_report: :environment do
    output_path = Rails.root.join("tmp/usage_report.csv")

    paid_subscriptions = Account::Subscription.paid.index_by(&:account_id)
    comped_account_ids = Account::BillingWaiver.pluck(:account_id).to_set

    CSV.open(output_path, "w") do |csv|
      csv << [ "Queenbee ID", "Account Name", "Sign Up Date", "Paid Date", "Comped", "Card Count", "Storage Used (Bytes)", "Last Active" ]

      Account.active.find_each do |account|
        subscription = paid_subscriptions[account.id]

        csv << [
          account.external_account_id,
          account.name,
          account.created_at.to_date,
          subscription&.created_at&.to_date,
          comped_account_ids.include?(account.id),
          account.cards_count,
          account.bytes_used,
          account.cards.maximum(:last_active_at)&.to_date
        ]
      end
    end

    puts "Report written to #{output_path}"
  end
end
