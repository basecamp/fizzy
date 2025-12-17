module Fizzy
  module Saas
    module Signup
      extend ActiveSupport::Concern

      included do
        attr_reader :queenbee_account
      end

      private
        def create_tenant
          @queenbee_account = Queenbee::Remote::Account.create!(queenbee_account_attributes)
          @queenbee_account.id.to_s
        end

        def handle_account_creation_error(error)
          @queenbee_account&.cancel
        end

        def queenbee_account_attributes
          {}.tap do |attributes|
            attributes[:product_name]   = "fizzy"
            attributes[:name]           = generate_account_name
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
    end
  end
end
