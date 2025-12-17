module Fizzy
  module Saas
    module Authorization
      module Controller
        extend ActiveSupport::Concern

        included do
          before_action :ensure_only_employees_can_access_non_production_remote_environments, if: :authenticated?
        end

        private
          def ensure_only_employees_can_access_non_production_remote_environments
            head :forbidden if Rails.env.staging? && !Current.identity.employee?
          end
      end

      module Identity
        extend ActiveSupport::Concern

        EMPLOYEE_DOMAINS = [ "@37signals.com", "@basecamp.com" ].freeze

        def employee?
          email_address.end_with?(*EMPLOYEE_DOMAINS)
        end
      end
    end
  end
end
