module Saas
  extend ActiveSupport::Concern

  included do
    helper_method :signups_allowed?
  end

  def signups_allowed?
    defined?(Signup) && defined?(saas)
  end
end
