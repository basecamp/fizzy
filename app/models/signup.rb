class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  PERMITTED_KEYS = %i[ full_name email_address password company_name ]

  # Input attribute
  attr_accessor :company_name

  # Input attributes when not using an existing identity
  attr_accessor :full_name, :email_address, :password

  # Input attribute when using an existing identity, output when creating new identity
  attr_accessor :signal_identity

  # Output attributes
  attr_reader :queenbee_account, :signal_account, :account, :user

  validate :validate_new_identity

  def initialize(...)
    @full_name = nil
    @email_address = nil
    @password = nil
    @company_name = nil
    @signal_identity = nil
    @queenbee_account = nil
    @account = nil
    @user = nil

    super
  end

  def process(destroy_existing_tenant: false)
    return false unless valid?

    create_signal_identity
    create_queenbee_account
    create_tenant(destroy_existing_tenant:)

    true
  rescue => error
    destroy_tenant
    destroy_queenbee_account
    destroy_signal_identity

    errors.add(:base, "An error occurred during signup: #{error.message}")

    false
  end

  def recognized?
    SignalId::Identity.find_by_email_address(email_address).present?
  end

  def tenant_name
    @tenant_name ||= @queenbee_account.id.to_s
  end

  def to_h
    {
      full_name:      full_name,
      email_address:  email_address,
      company_name:   company_name
    }.compact_blank
  end

  private
    def create_signal_identity
      unless signal_identity.present?
        SignalId::Database.on_master do
          @signal_identity = build_new_identity.tap(&:save!)
        end
      end
    end

    def create_queenbee_account
      @queenbee_account = Queenbee::Remote::Account.create!(queenbee_account_attributes)
      SignalId::Database.on_master do
        @signal_account = SignalId::Account.find_by(queenbee_id: @queenbee_account.id)
      end
    end

    def create_tenant(destroy_existing_tenant: false, &block)
      ApplicationRecord.destroy_tenant(tenant_name) if destroy_existing_tenant
      ApplicationRecord.create_tenant(tenant_name) do
        @account = Account.create_with_admin_user(queenbee_id: queenbee_account.id)
        @account.setup_basic_template
        @user = User.first
      end
    end

    def destroy_tenant
      if queenbee_account && ApplicationRecord.tenant_exist?(tenant_name)
        ApplicationRecord.destroy_tenant(tenant_name)
        @account = nil
        @user = nil
      end
    end

    def destroy_queenbee_account
      queenbee_account&.cancel
      @queenbee_account = nil
    end

    def destroy_signal_identity
      SignalId::Database.on_master do
        signal_identity&.destroy
      end
      @signal_identity = nil
    end

    def validate_new_identity
      unless signal_identity.present?
        build_new_identity.tap do |identity|
          unless identity.valid?
            identity.errors.each { |error| errors.add(error.attribute, error.message) }
          end
        end
      end
    end

    def build_new_identity
      SignalId::Identity.new do |identity|
        identity.name = full_name || email_address
        identity.email_address = email_address
        identity.username = email_address
        identity.password = password
      end
    end

    def queenbee_account_attributes
      {
        skip_remote: true, # Fizzy creates its own local account
        product_name: SignalId.product.name,
        name: queenbee_account_name,
        owner_identity_id: signal_identity.id,
        trial: false,
        subscription: subscription_attributes,
        remote_request: request_attributes
      }
    end

    def subscription_attributes
      subscription = FreeV1Subscription
      { name: subscription.to_param, price: subscription.price }
    end

    def request_attributes
      { remote_address: Current.ip_address, user_agent: Current.user_agent, referrer: Current.referrer }
    end

    def queenbee_account_name
      name = company_name.presence || signal_identity.name
      name += " (Beta)" if Rails.env.beta?
      name
    end
end
