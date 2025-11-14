class Account < ApplicationRecord
  include Entropic, Seedeable

  has_one :join_code
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, through: :boards

  has_many_attached :uploads

  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_admin_user(account:, owner:)
      create!(**account).tap do |account|
        User.create!(account: account, role: :system, name: "System")
        User.create!(**owner.reverse_merge(role: "admin", account: account))
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
