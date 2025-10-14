require "queenbee/testing/mocks"

Queenbee::Remote::Account.class_eval do
  # because we use the account ID as the tenant name, we need it to be unique in each test to avoid
  # parallelized tests clobbering each other.
  def next_id
    super + Random.rand(1000000)
  end
end
