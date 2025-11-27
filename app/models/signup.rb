class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity
  attr_reader :account, :user

  with_options on: :completion do
    validates_presence_of :full_name, :identity
  end

  def initialize(...)
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
        @tenant = create_tenant
        create_account
        true
      rescue => error
        destroy_account
        handle_account_creation_error(error)

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
    # Override to customize the handling of external accounts associated to the account.
    def create_tenant
      nil
    end

    # Override to inject custom handling for account creation errors
    def handle_account_creation_error(error)
    end

    def create_account
      @account = Account.create_with_admin_user(
        account: {
          external_account_id: @tenant,
          name: generate_account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :admin)
      @account.setup_customer_template
    end

    def generate_account_name
      AccountNameGenerator.new(identity: identity, name: full_name).generate
    end


    def destroy_account
      @account&.destroy!

      @user = nil
      @account = nil
      @tenant = nil
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
