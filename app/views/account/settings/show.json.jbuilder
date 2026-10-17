json.(@account, :id, :name, :cards_count)
json.created_at @account.created_at.utc
json.auto_postpone_period_in_days @account.entropy.auto_postpone_period_in_days
json.single_sign_on_group @account.single_sign_on_group
