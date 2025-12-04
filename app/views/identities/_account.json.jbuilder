json.cache! account do
  json.(account, :id, :name, :external_account_id)
  json.created_at account.created_at.utc
end
