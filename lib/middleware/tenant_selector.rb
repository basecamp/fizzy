# frozen_string_literal: true

module Middleware
  class TenantSelector
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      slug = request.subdomain
      if slug.blank?
        Tenant.while_untenanted do
          @app.call(env)
        end
      elsif (tenant = Tenant.find_by_slug(slug))
        tenant.while_tenanted do
          @app.call(env)
        end
      else
        Rails.logger.info("TenantSelector: Tenant not found for slug #{slug.inspect}")
        Rack::NotFound.new("public/404.html").call(env)
      end
    end
  end
end
