json.accounts @identity.users do |user|
  json.partial! "my/identities/account", account: user.account
  json.user user, partial: "users/user", as: :user
end
