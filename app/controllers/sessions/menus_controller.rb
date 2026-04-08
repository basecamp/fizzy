class Sessions::MenusController < ApplicationController
  disallow_account_scope

  layout "public"

  def show
    @accounts = Current.identity.accounts.active

    if @accounts.one?
      redirect_to root_url(script_name: @accounts.first.slug) and return
    end

    # When user has no accounts: auto-create one for Forward Auth user so they never see the no-accounts page.
    if @accounts.empty? && forward_auth_auto_create_account?
      account = create_account_for_forward_auth_identity
      redirect_to root_url(script_name: account.slug) and return if account
    end
  end

  private

    def forward_auth_config
      Rails.application.config.forward_auth
    end

    def forward_auth_auto_create_account?
      cfg = forward_auth_config
      cfg.is_a?(ForwardAuth::Config) && cfg.enabled? && cfg.auto_provision? && cfg.auto_create_account?
    end

    def create_account_for_forward_auth_identity
      cfg = forward_auth_config
      owner_name = email_local_part(Current.identity.email_address)
      account = Account.create_with_owner(
        account: { name: cfg.auto_create_account_name },
        owner: { identity: Current.identity, name: owner_name }
      )
      if cfg.use_email_local_part_and_lock_email? && Current.identity.respond_to?(:email_locked=)
        Current.identity.update_column(:email_locked, true)
      end
      account
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[ForwardAuth] Auto-create account failed: #{e.message}"
      nil
    end

    def email_local_part(email_address)
      email_address.to_s.split("@", 2).first.presence || email_address
    end
end
