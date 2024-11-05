class Project < ApplicationRecord
  include Bucketable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_one :account, through: :creator

  validates_presence_of :name

  def title
    name
  end
end
