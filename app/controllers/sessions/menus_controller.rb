class Sessions::MenusController < ApplicationController
  require_untenanted_access

  before_action(if: :render_as_menu_section?) { request.variant = :menu_section }

  layout "public"

  def show
    @memberships = Current.identity.memberships

    if params[:without]
      @memberships = @memberships.where.not(tenant: params[:without])
    end

    if @memberships.one? && !render_as_menu_section?
      redirect_to root_url(script_name: "/#{@memberships.first.tenant}")
    end
  end

  private
    def render_as_menu_section?
      params[:menu_section]
    end
end
