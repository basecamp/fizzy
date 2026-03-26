class Board::AgentBootstrap < ApplicationRecord
  belongs_to :account
  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :claimed_by_identity, class_name: "Identity", optional: true

  has_secure_token

  enum :permission, %w[ read write ].index_by(&:itself), default: :write
  enum :involvement, Access.involvements, default: :watching

  scope :active, -> { where(claimed_at: nil, expires_at: Time.current...) }

  validates :expires_at, presence: true

  def expired?
    expires_at <= Time.current
  end

  def claimed?
    claimed_at.present?
  end

  def claimable?
    !claimed? && !expired?
  end

  def claim!(email_address:, name:, profile_name: nil)
    raise ActiveRecord::RecordNotFound unless claimable?

    transaction do
      lock!
      raise ActiveRecord::RecordNotFound unless claimable?

      identity = Identity.find_or_initialize_by(email_address: email_address)
      ensure_claimable_identity!(identity)
      identity.save! if identity.new_record?

      user = identity.users.find_or_initialize_by(account: account)
      if user.new_record?
        user.name = name
        user.role = :member
        user.verified_at ||= Time.current
        user.save!
      elsif !user.active?
        user.update!(identity: identity, active: true)
      end

      board.accesses.find_or_create_by!(user: user) do |access|
        access.account = account
        access.involvement = involvement
      end.update!(involvement: involvement)

      access_token = identity.access_tokens.create!(
        description: "Fizzy CLI#{profile_name.present? ? " (#{profile_name})" : " (#{name})"}",
        permission: permission
      )

      update!(claimed_at: Time.current, claimed_by_identity: identity)

      { identity:, user:, access_token: }
    end
  end

  private
    def ensure_claimable_identity!(identity)
      return if identity.new_record?
      return if identity.users.where(account: account).exists? && identity.users.where.not(account: account).none?

      errors.add(:base, "Bootstrap claims cannot reuse an identity from another account")
      raise ActiveRecord::RecordInvalid, self
    end
end
