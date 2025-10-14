class My::MenusController < ApplicationController
  include FilterScoped

  def show
    fresh_when etag: [ @user_filtering, Current.identity_token ]
  end
end
