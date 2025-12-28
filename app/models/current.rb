# rbs_inline: enabled

class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  delegate :identity, to: :session, allow_nil: true

  # @rbs!
  #   attr_reader session: (Session?)
  #   attr_accessor user: (User?)
  #   attr_accessor account: (Account?)
  #
  #   def self.session: () -> (Session)
  #   def self.user: () -> (User)
  #   def self.account: () -> (Account)
  #
  #   def identity: () -> Identity?
  #
  #   def with: (untyped) ?{ () -> untyped } -> untyped
  # @end

  def session=(value)
    super(value)

    if value.present? && account.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  #: (untyped) ?{ () -> untyped } -> self
  def with_account(value, &)
    with(account: value, &)
  end

  #: (untyped) ?{ () -> untyped } -> self
  def without_account(&)
    with(account: nil, &)
  end
end
