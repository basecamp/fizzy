class Identity::AccessToken < ApplicationRecord
  belongs_to :identity
  belongs_to :session

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  before_validation :build_session, on: :create

  private
    def build_session
      self.session = identity.sessions.build(user_agent: "Access Token")
    end
end
