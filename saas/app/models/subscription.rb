class Subscription < Queenbee::Subscription
  SHORT_NAMES = %w[ FreeV1 ]

  def self.short_name
    name.demodulize
  end

  class FreeV1 < Subscription
    property :proper_name,  "Free Subscription"
    property :price,        0
    property :frequency,    "yearly"
  end
end
