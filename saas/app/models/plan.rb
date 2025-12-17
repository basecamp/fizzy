class Plan
  PLANS = {
    free_v1: { name: "Free", price: 0, card_limit: 1000, storage_limit: 1.gigabytes },
    monthly_v1: { name: "Unlimited", price: 20, card_limit: Float::INFINITY, storage_limit: 5.gigabytes, stripe_price_id: ENV["STRIPE_MONTHLY_V1_PRICE_ID"] }
  }

  attr_reader :key, :name, :price, :card_limit, :storage_limit, :stripe_price_id

  class << self
    def all
      @all ||= PLANS.map { |key, properties| new(key: key, **properties) }
    end

    def free
      @free ||= find(:free_v1)
    end

    def paid
      @paid ||= find(:monthly_v1)
    end

    def find(key)
      @all_by_key ||= all.index_by(&:key).with_indifferent_access
      @all_by_key[key]
    end

    alias [] find
  end

  def initialize(key:, name:, price:, card_limit:, storage_limit:, stripe_price_id: nil)
    @key = key
    @name = name
    @price = price
    @card_limit = card_limit
    @storage_limit = storage_limit
    @stripe_price_id = stripe_price_id
  end

  def free?
    price.zero?
  end

  def paid?
    !free?
  end

  def limit_cards?
    card_limit != Float::INFINITY
  end
end
