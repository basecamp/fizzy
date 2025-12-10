module SetTenant
  extend ActiveSupport::Concern

  included do
    helper_method :single_tenant?
  end

  private
    def single_tenant?
      ENV.fetch("SINGLE_TENANT", "false") == "true"
    end
end
