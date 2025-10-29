module Restricted
  extend ActiveSupport::Concern

  included do
    unless Rails.env.development?
      http_basic_authenticate_with \
        name: Rails.env.test? ? "testname" : Rails.application.credentials.account_signup_http_basic_auth.name,
        password: Rails.env.test? ? "testpassword" : Rails.application.credentials.account_signup_http_basic_auth.password
    end
  end
end
