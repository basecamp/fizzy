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
  has_many :github_integrations, dependent: :destroy
  has_one :github_setting, class_name: "Account::GithubSetting", dependent: :destroy
  has_many :slack_integrations, dependent: :destroy
  has_one :slack_setting, class_name: "Account::SlackSetting", dependent: :destroy

  before_create :assign_external_account_id
  after_create :create_join_code
  after_create :create_github_setting
  after_create :create_slack_setting

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.with_defaults(role: :owner, verified_at: Time.current))
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

    def create_github_setting
      build_github_setting.save!
    end

    def create_slack_setting
      build_slack_setting.save!
    end
end
