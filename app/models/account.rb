class Account < ApplicationRecord
  include Account::Storage, Entropic, MultiTenantable, Seedeable

  has_one :join_code
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :exports, class_name: "Account::Export", dependent: :destroy

  before_create :assign_external_account_id
  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.reverse_merge(role: "owner", verified_at: Time.current))
      end
    end
  end

  def slug
    "/#{AccountSlug.encode(external_account_id)}"
  end

  def account
    self
  end

  def system_user
    users.find_by!(role: :system)
  end

  private
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end
