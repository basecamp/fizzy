class Identity::AccessToken < ApplicationRecord
  belongs_to :identity

  has_secure_token
  enum :permission, %w[ read write ].index_by(&:itself), default: :read

  def allows?(method)
    method.in?(%w[ GET HEAD ]) || write?
  end
end
