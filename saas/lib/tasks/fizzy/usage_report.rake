require "csv"

namespace :saas do
  desc "Generate a CSV usage report for all active accounts"
  task usage_report: :environment do
    output_path = Rails.root.join("tmp/usage_report.csv")

    CSV.open(output_path, "w") do |csv|
      csv << [ "Queenbee ID", "Account Name", "Sign Up Date", "Paid Date", "Comped", "Card Count", "Storage Used (Bytes)", "Last Active" ]

      Account.active.includes(:storage_total).in_batches do |batch|
        batch_ids = batch.pluck(:id)
        paid_dates = Account::Subscription.paid.where(account_id: batch_ids)
          .group(:account_id).minimum(:created_at)
        comped_account_ids = Account::BillingWaiver.where(account_id: batch_ids)
          .pluck(:account_id).to_set
        last_active_dates = Card.where(account_id: batch_ids)
          .group(:account_id).maximum(:last_active_at)

        batch.each do |account|
          csv << [
            account.external_account_id,
            account.name,
            account.created_at.to_date,
            paid_dates[account.id]&.to_date,
            comped_account_ids.include?(account.id),
            account.cards_count,
            account.bytes_used,
            last_active_dates[account.id]&.to_date
          ]
        end
      end
    end

    puts "Report written to #{output_path}"
  end
end
