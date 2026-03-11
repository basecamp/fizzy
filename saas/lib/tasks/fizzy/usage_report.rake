require "csv"

namespace :saas do
  desc "Generate a CSV usage report for all active accounts"
  task usage_report: :environment do
    output_path = Rails.root.join("tmp/usage_report.csv")

    paid_subscriptions = Account::Subscription.paid.index_by(&:account_id)

    CSV.open(output_path, "w") do |csv|
      csv << [ "Queenbee ID", "Sign Up Date", "Paid Date", "Card Count", "Storage Used (Bytes)", "Last Active" ]

      Account.active.find_each do |account|
        subscription = paid_subscriptions[account.id]

        csv << [
          account.external_account_id,
          account.created_at.to_date,
          subscription&.created_at&.to_date,
          account.cards_count,
          account.bytes_used,
          account.cards.maximum(:last_active_at)&.to_date
        ]
      end
    end

    puts "Report written to #{output_path}"
  end
end
