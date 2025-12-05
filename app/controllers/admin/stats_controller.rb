class Admin::StatsController < AdminController
  layout "public"

  def show
    @accounts_total = Account.count
    @accounts_last_7_days = Account.where(created_at: 7.days.ago..).count
    @accounts_last_24_hours = Account.where(created_at: 24.hours.ago..).count

    @identities_total = Identity.count
    @identities_last_7_days = Identity.where(created_at: 7.days.ago..).count
    @identities_last_24_hours = Identity.where(created_at: 24.hours.ago..).count

    @top_accounts = Account
      .where("cards_count > 0")
      .order(cards_count: :desc)
      .limit(20)

    @recent_accounts = Account.order(created_at: :desc).limit(10)

    @api_tokens_total = ApiToken.count
    @api_tokens_active = ApiToken.active.count
    @api_tokens_expired = ApiToken.expired.count
    @recent_api_tokens = ApiToken.includes(:account, :user).order(created_at: :desc).limit(10)
  end
end
