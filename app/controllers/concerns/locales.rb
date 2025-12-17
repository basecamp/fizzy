module Locales
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private
  def set_locale
    locale = params[:locale] || cookies[:locale] || extract_locale_from_accept_language || I18n.default_locale
    locale = locale.to_sym

    if I18n.available_locales.include?(locale)
      I18n.locale = locale
      cookies[:locale] = { value: locale.to_s, expires: 1.year.from_now }
    else
      I18n.locale = I18n.default_locale
    end
  end

  def extract_locale_from_accept_language
    accept_language = request.env["HTTP_ACCEPT_LANGUAGE"]
    return nil unless accept_language

    languages = accept_language.scan(/[a-z]{2}(?:-[A-Z]{2})?/i).map(&:downcase)
    return :pl if languages.any? { |lang| lang.start_with?("pl") }
    return :en if languages.any?
    nil
  end
end
