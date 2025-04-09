class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user, optional: true
end
