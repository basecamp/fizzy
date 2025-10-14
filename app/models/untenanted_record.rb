class UntenantedRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :untenanted }
end
