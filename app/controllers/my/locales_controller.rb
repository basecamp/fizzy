# frozen_string_literal: true

class My::LocalesController < ApplicationController
  def update
    locale = resolve_locale_param
    if locale
      session[:locale] = locale.to_s
      Current.identity.update_column(:locale, locale.to_s)
      I18n.locale = locale
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: user_path(Current.user) }
      format.json { head :no_content }
    end
  end

  private
    def resolve_locale_param
      return nil if params[:locale].blank?
      sym = params[:locale].to_s.underscore.to_sym
      Rails.application.config.i18n.available_locales.include?(sym) ? sym : nil
    end
end
