module Fizzy
  def self.saas?
    defined?(Fizzy::Saas::Engine)
  end
end
