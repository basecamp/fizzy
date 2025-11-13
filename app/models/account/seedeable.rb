module Account::Seedeable
  extend ActiveSupport::Concern

  def setup_customer_template
    Account::Seeder.new(self, users.active.where(role: :admin).first).seed
  end
end
