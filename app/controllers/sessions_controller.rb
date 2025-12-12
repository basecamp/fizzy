class SessionsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "public"

  def new
  end

  def create
    # Local development: simple username login creates account on-the-fly
    username = params[:username].to_s.strip.downcase.gsub(/\s+/, '_')
    
    if username.blank?
      redirect_to new_session_path, alert: "Please enter a username"
      return
    end
    
    # Validate username format
    unless username.match?(/\A[a-zA-Z0-9_]+\z/)
      redirect_to new_session_path, alert: "Username can only contain letters, numbers, and underscores"
      return
    end
    
    # Find or create identity by username (no email required)
    identity = Identity.find_or_initialize_by(username: username)
    
    if identity.new_record?
      identity.save!
    end
    
    # Find or create user's account
    if identity.users.empty?
      account = Account.create_with_owner(
        account: { name: "#{username}'s Workspace" },
        owner: { name: username, identity: identity }
      )
    else
      account = identity.users.first.account
    end
    
    # Create session and redirect
    session = identity.sessions.create!
    cookies.signed[:session_token] = { value: session.signed_id, httponly: true, secure: true }
    redirect_to account.slug
  end

  def destroy
    terminate_session
    redirect_to_logout_url
  end

  private
    def email_address
      params.expect(:email_address)
    end
end
