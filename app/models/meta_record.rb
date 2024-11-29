class MetaRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :meta }
end
