class Bucket < ApplicationRecord
  include Accessible

  belongs_to :account
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_many :bubbles, dependent: :destroy
  has_many :tags, -> { distinct }, through: :bubbles
  has_many :views, dependent: :destroy

  after_create -> { views.create! }

  validates_presence_of :name
end
