class Users::JoinsController < ApplicationController
  require_access_without_a_user

  before_action :set_join_code, :ensure_join_code_is_valid

  layout "public"

  def new
  end

  def create
    @join_code.redeem do
      User.create!(user_params.merge(membership: Current.membership))
    end

    redirect_to landing_path
  end

  private
    def set_join_code
      @join_code = Account::JoinCode.active.find_by(code: Current.membership.join_code)
    end

    def ensure_join_code_is_valid
      unless @join_code&.active?
        redirect_to unlink_membership_url(script_name: nil, membership_id: Current.membership.signed_id(purpose: :unlinking))
      end
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
