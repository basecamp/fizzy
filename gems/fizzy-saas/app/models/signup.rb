class Signup
  MEMBERSHIP_PURPOSE = :account_creation

  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity, :membership_id, :account_name
  attr_reader :queenbee_account, :account, :user, :tenant, :membership

  with_options on: :membership_creation do
    validates_presence_of :full_name, :identity
  end

  with_options on: :completion do
    validates_presence_of :full_name, :account_name, :identity, :membership
  end

  def initialize(...)
    @full_name = nil
    @email_address = nil
    @tenant = nil
    @account = nil
    @user = nil
    @queenbee_account = nil
    @membership = nil
    @membership_id = nil
    @identity = nil
    @account_name = nil

    super

    if @identity
      @email_address = @identity.email_address
      @membership = identity.memberships.find_signed(membership_id, purpose: MEMBERSHIP_PURPOSE)
      @tenant = membership&.tenant
    end
  end

  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link
  end

  def create_membership
    if valid?(:membership_creation)
      begin
        create_queenbee_account

        @membership = identity.memberships.create!(tenant: tenant)
        @membership_id = @membership.signed_id(purpose: MEMBERSHIP_PURPOSE)
      rescue => error
        destroy_queenbee_account

        @membership&.destroy
        @membership = nil
        @membership_id = nil

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)

        false
      end
    else
      false
    end
  end

  def complete
    if valid?(:completion)
      begin
        create_tenant

        true
      rescue => error
        destroy_tenant

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)

        false
      end
    else
      false
    end
  end

  private
    def create_queenbee_account
      @account_name = AccountNameGenerator.new(identity: identity, name: full_name).generate
      @queenbee_account = Queenbee::Remote::Account.create!(queenbee_account_attributes)
      @tenant = queenbee_account.id.to_s
    end

    def destroy_queenbee_account
      @queenbee_account&.cancel
      @queenbee_account = nil
    end

    def create_tenant
      ApplicationRecord.create_tenant(tenant) do
        @account = Account.create_with_admin_user(
          account: {
            external_account_id: tenant,
            name: account_name
          },
          owner: {
            name: full_name,
            membership_id: membership.id
          }
        )
        @user = User.find_by!(role: :admin)
        @account.setup_customer_template
      end
    end

    def destroy_tenant
      if tenant.present? && ApplicationRecord.tenant_exist?(tenant)
        ApplicationRecord.destroy_tenant(tenant)
      end

      @user = nil
      @account = nil
      @tenant = nil
    end

    def queenbee_account_attributes
      {}.tap do |attributes|
        attributes[:product_name]   = "fizzy"
        attributes[:name]           = account_name
        attributes[:owner_name]     = full_name
        attributes[:owner_email]    = email_address

        attributes[:trial]          = true
        attributes[:subscription]   = subscription_attributes
        attributes[:remote_request] = request_attributes

        # # TODO: Terms of Service
        # attributes[:terms_of_service] = true

        # We've confirmed the email
        attributes[:auto_allow]     = true

        # Tell Queenbee to skip the request to create a local account. We've created it ourselves.
        attributes[:skip_remote]    = true
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
