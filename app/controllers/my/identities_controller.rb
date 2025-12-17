class My::IdentitiesController < ApplicationController
  disallow_account_scope

  def show
    @identity = Current.identity
  end
end
