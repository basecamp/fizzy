class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity, :skip_account_seeding
  attr_reader :account, :user

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, :identity, presence: true, on: :completion
  validates :full_name, length: { maximum: 240 }

  def initialize(...)
    super

    @email_address = @identity.email_address if @identity
  end

  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link for: :sign_up
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
      @account = Account.create_with_owner(
        account: {
          external_account_id: @tenant,
          name: generate_account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :owner)
      @account.setup_customer_template unless skip_account_seeding
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
