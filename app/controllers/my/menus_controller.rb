class My::MenusController < ApplicationController
  include FilterScoped

  def show
    fresh_when etag: [ @user_filtering, Current.session ]
  end
end
