class Identity::AccessToken < ApplicationRecord
  belongs_to :identity

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  def session
    identity.sessions.find_or_create_by! user_agent: session_user_agent
  end

  private
    # Overload the user_agent identification for access token session reuse.
    # This allows us to easily reuse a single session record per access token.
    def session_user_agent
      "access-token-#{id}"
    end
end
