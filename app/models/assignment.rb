class Assignment < ApplicationRecord
  belongs_to :card, touch: true

  belongs_to :assignee, class_name: "User"
  belongs_to :assigner, class_name: "User"
end
