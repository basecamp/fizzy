class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :company_name, :full_name, :email_address, :identity
  attr_reader :queenbee_account, :account, :user, :tenant

  with_options on: :identity_creation do
    validates_presence_of :email_address
  end

  with_options on: :completion do
    validates_presence_of :company_name, :full_name, :identity
  end


  def initialize(...)
    @company_name = nil
    @full_name = nil
    @email_address = nil
    @password = nil
    @tenant = nil
    @account = nil
    @user = nil
    @queenbee_account = nil

    super
  end

  def create_identity
    return false unless valid?(:identity_creation)

    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link
  end

  def complete
    return false unless valid?(:completion)

    create_queenbee_account
    create_tenant

    identity.link_to(tenant)

    true
  rescue => error
    destroy_tenant
    destroy_queenbee_account

    errors.add(:base, "An error occurred during signup: #{error.message}")
    Rails.logger.error(error)
    Rails.logger.error(error.backtrace.join("\n"))

    false
  end

  private
    def create_queenbee_account
      @queenbee_account = Queenbee::Remote::Account.create!(queenbee_account_attributes)
    end

    def destroy_queenbee_account
      @queenbee_account&.cancel
      @queenbee_account = nil
    end

    def create_tenant
      @tenant = queenbee_account.id.to_s

      ApplicationRecord.create_tenant(tenant) do
        @account = Account.create_with_admin_user(
          account: {
            external_account_id: tenant,
            name: company_name
          },
          owner: {
            name: full_name,
            email_address: email_address
          }
        )
        @user = User.find_by!(role: :admin)
        @account.setup_basic_template
      end
    end

    def destroy_tenant
      if tenant.present? && ApplicationRecord.tenant_exist?(tenant)
        ApplicationRecord.destroy_tenant(tenant)
      end

      @account = nil
      @user = nil
      @tenant = nil
    end

    def queenbee_account_attributes
      {}.tap do |attributes|
        # Tell Queenbee to skip the request to create a local account. We've created it ourselves.
        attributes[:skip_remote]    = true

        # # TODO: once we are doing our own email validation, consider setting this
        # # Queenbee should not do spam checks on this account, we've done our own.
        # attributes[:auto_allow]     = true

        # # TODO: Terms of Service
        # attributes[:terms_of_service] = true

        attributes[:product_name]   = "fizzy"
        attributes[:name]           = email_address
        attributes[:owner_name]     = email_address
        attributes[:owner_email]    = email_address

        attributes[:trial]          = true
        attributes[:subscription]   = subscription_attributes
        attributes[:remote_request] = request_attributes
      end
    end

    def subscription_attributes
      subscription = FreeV1Subscription

      {}.tap do |attributes|
        attributes[:name]  = subscription.to_param
        attributes[:price] = subscription.price
      end
    end

    def request_attributes
      {}.tap do |attributes|
        attributes[:remote_address] = Current.ip_address
        attributes[:user_agent]     = Current.user_agent
        attributes[:referrer]       = Current.referrer
      end
    end
end
