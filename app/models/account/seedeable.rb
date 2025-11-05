module Account::Seedeable
  extend ActiveSupport::Concern

  def setup_customer_template
    Account::Seeder.new(self, User.active.first).seed
  end
end
