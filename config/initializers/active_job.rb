# frozen_string_literal: true

# inspired from code in ActiveRecord::Tenanted
module FizzyActiveJobExtensions
  extend ActiveSupport::Concern

  prepended do
    attr_reader :account
  end

  def initialize(...)
    super
    @account = Current.account
  end

  def serialize
    super.merge({ "account" => @account&.to_gid })
  end

  def deserialize(job_data)
    super
    if _account = job_data.fetch("account", nil)
      @account = GlobalID::Locator.locate(_account)
    end
  end

  def perform_now
    if account.present?
      Current.with_account(account) { super }
    else
      super
    end
  end
end

ActiveSupport.on_load(:active_job) do
  prepend FizzyActiveJobExtensions
end
