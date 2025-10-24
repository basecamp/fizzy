class Sessions::MenusController < ApplicationController
  require_untenanted_access

  layout "public"

  def show
    if params[:menu_section]
      request.variant = :menu_section
    end

    @memberships = Current.identity.memberships

    if params[:without]
      @memberships = @memberships.where.not(tenant: params[:without])
    end
  end
end
