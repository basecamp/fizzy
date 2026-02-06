class Sessions::MenusController < ApplicationController
  disallow_account_scope

  layout "public"

  def show
    @accounts = Current.identity.accounts.active

    if @accounts.one?
      redirect_to root_url(script_name: @accounts.first.slug)
    end
  end
end
