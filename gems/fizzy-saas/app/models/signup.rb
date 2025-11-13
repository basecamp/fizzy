class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity
  attr_reader :queenbee_account, :account, :user

  with_options on: :completion do
    validates_presence_of :full_name, :identity
  end

  def initialize(...)
    @full_name = nil
    @email_address = nil
    @account = nil
    @user = nil
    @queenbee_account = nil
    @identity = nil

    super

    @email_address = @identity.email_address if @identity
  end

  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link
  end

  def complete
    if valid?(:completion)
      begin
        create_queenbee_account
        create_account

        true
      rescue => error
        destroy_account
        destroy_queenbee_account

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")

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

    def create_account
      @account = Account.create_with_admin_user(
        account: {
          external_account_id: @tenant,
          name: @account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :admin)
      @account.setup_customer_template
    end

    def destroy_account
      @account&.destroy!

      @user = nil
      @account = nil
      @tenant = nil
    end

    def queenbee_account_attributes
      {}.tap do |attributes|
        attributes[:product_name]   = "fizzy"
        attributes[:name]           = @account_name
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
