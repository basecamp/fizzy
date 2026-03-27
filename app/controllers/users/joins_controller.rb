class Users::JoinsController < ApplicationController
  wrap_parameters :user, include: %i[ name avatar ]

  layout "public"

  def new
  end

  def create
    Current.user.update!(user_params)

    respond_to do |format|
      format.html { redirect_to landing_path }
      format.json { head :no_content }
    end
  end

  private
    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
