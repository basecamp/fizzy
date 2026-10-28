class My::IdentitiesController < ApplicationController
  disallow_account_scope
  allow_account_bound_grants_unscoped

  # An account-bound grant sees its own account alone: it was consented to for
  # that one, and listing the rest would tell the app about every account the
  # person belongs to.
  def show
    @identity = Current.identity
    @users = @identity.users_with_active_accounts
    @users = @users.where(account_id: Current.access_token.account_id) if Current.access_token&.account_bound?
  end
end
