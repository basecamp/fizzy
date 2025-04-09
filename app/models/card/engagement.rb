class Card::Engagement < ApplicationRecord
  belongs_to :card, class_name: "::Card", touch: true
end
