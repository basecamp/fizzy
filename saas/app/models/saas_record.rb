class SaasRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :saas, reading: :saas }
end
