class Account < ApplicationRecord
  include Joinable

  has_many :buckets, dependent: :destroy
  has_many :bubbles, through: :buckets

  has_many :users, dependent: :destroy do
    def system
      find_or_create_system_user(proxy_association.owner)
    end
  end

  has_many :workflows, dependent: :destroy
  has_many :stages, through: :workflows, class_name: "Workflow::Stage"

  has_many :pop_reasons, dependent: :destroy, class_name: "Pop::Reason" do
    def labels
      pluck(:label).presence || [ Pop::Reason::FALLBACK_LABEL ]
    end
  end

  has_many :tags, dependent: :destroy

  has_many_attached :uploads
end
