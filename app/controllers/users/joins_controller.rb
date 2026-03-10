class Users::JoinsController < ApplicationController
  wrap_parameters :user, include: %i[ name avatar ]

  layout "public"

  def new
  end

  def create
    Current.user.update!(user_params)
    redirect_to landing_path
  end

  private
    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
