class Identity::AccessToken < ApplicationRecord
  belongs_to :identity

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read
end
