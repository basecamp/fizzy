json.accounts @identity.users do |user|
  json.partial! "identities/account", account: user.account
  json.user do
    json.partial! "users/user", user: user
  end  
end
