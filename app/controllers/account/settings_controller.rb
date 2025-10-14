class Account::SettingsController < ApplicationController
  def show
    @account = Account.sole
    @users = User.active.alphabetically
  end
end
