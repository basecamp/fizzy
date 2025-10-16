class FizzySaasRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :fizzy_sass }
end
