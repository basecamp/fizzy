class JoinCodesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_join_code
  before_action :ensure_join_code_is_valid

  layout "public"

  def new
  end

  def create
    identity = Identity.find_or_create_by!(email_address: params.expect(:email_address))

    @join_code.redeem { |account| identity.join(account) } unless identity.member_of?(@join_code.account)
    user = User.active.find_by!(account: @join_code.account, identity: identity)

    if identity == Current.identity && user.setup?
      redirect_to landing_url(script_name: @join_code.account.slug)
    elsif identity == Current.identity
      redirect_to new_users_join_url(script_name: @join_code.account.slug)
    else
      logout_and_send_new_magic_link(identity)
      redirect_to session_magic_link_url(script_name: nil)
    end
  end

  private
    def set_join_code
      @join_code ||= Account::JoinCode.find_by(code: params.expect(:code), account: Current.account)
    end

    def ensure_join_code_is_valid
      if @join_code.nil?
        head :not_found
      elsif !@join_code.active?
        render :inactive, status: :gone
      end
    end

    def logout_and_send_new_magic_link(identity)
      terminate_session if Current.identity

      magic_link = identity.send_magic_link
      serve_development_magic_link(magic_link)

      session[:return_to_after_authenticating] = new_users_join_url(script_name: @join_code.account.slug)
    end
end
