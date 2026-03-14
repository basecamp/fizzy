class Admin::StatsController < AdminController
  layout "public"

  def show
    @accounts_total = Account.count
    @accounts_last_7_days = Account.where(created_at: 7.days.ago..).count
    @accounts_last_24_hours = Account.where(created_at: 24.hours.ago..).count

    @paid_accounts_total = Account::Subscription.paid.distinct.count(:account_id)
    @paid_accounts_last_7_days = Account::Subscription.paid.where(created_at: 7.days.ago..).distinct.count(:account_id)
    @paid_accounts_last_24_hours = Account::Subscription.paid.where(created_at: 24.hours.ago..).distinct.count(:account_id)

    @identities_total = Identity.count
    @identities_last_7_days = Identity.where(created_at: 7.days.ago..).count
    @identities_last_24_hours = Identity.where(created_at: 24.hours.ago..).count

    @top_accounts = Account
      .where("cards_count > 0")
      .order(cards_count: :desc)
      .limit(20)

    @recent_accounts = Account.order(created_at: :desc).limit(10)
  end
end
