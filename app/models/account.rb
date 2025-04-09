class Account < ApplicationRecord
  include ClosureReasons, Joinable

  has_many :collections, dependent: :destroy
  has_many :cards, through: :collections

  has_many :users, dependent: :destroy do
    def system
      find_or_create_system_user(proxy_association.owner)
    end
  end

  has_many :comments, through: :users

  has_many :workflows, dependent: :destroy
  has_many :stages, through: :workflows, class_name: "Workflow::Stage"

  has_many :tags, dependent: :destroy

  has_many_attached :uploads
end
