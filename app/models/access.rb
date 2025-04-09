class Access < ApplicationRecord
  belongs_to :collection
  belongs_to :user

  enum :involvement, %i[ access_only watching everything ].index_by(&:itself)
end
