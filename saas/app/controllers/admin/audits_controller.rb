class Admin::AuditsController < ::AdminController
  private
    # Extend Fizzy's authentication to support auditor bearer tokens.
    def require_authentication
      authenticate_by_audit_bearer_token || super
    end

    def authenticate_by_audit_bearer_token
      if auditor = auditor_from_bearer_token
        Current.identity = auditor
      end
    end

    def find_current_auditor
      Current.identity
    end
end
