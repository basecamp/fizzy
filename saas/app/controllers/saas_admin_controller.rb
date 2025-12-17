class SaasAdminController < ::AdminController
  private
    def find_current_auditor
      Current.identity
    end
end
