class Pop < ApplicationRecord
  belongs_to :bubble, touch: true
  belongs_to :user, optional: true
end
