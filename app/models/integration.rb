class Integration < ApplicationRecord
  belongs_to :owner, class_name: "User"

  store :data, coder: JSON
end
