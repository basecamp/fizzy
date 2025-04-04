class Pop::Reason < ApplicationRecord
  belongs_to :account

  FALLBACK_LABEL = "Done"
end
