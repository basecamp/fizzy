class Account < ApplicationRecord
  include Entropic, Seedeable

  has_one :join_code
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :columns, dependent: :destroy

  has_many_attached :uploads

  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_admin_user(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.reverse_merge(role: "admin"))
      end
    end
  end

  def slug
    "/#{external_account_id}"
  end

  def account
    self
  end
end
