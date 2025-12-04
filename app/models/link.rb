class Link
  UNFURLERS = [
    FizzyUnfurler,
  ]

  attr_reader :uri, :metadata, :user

  def self.unfurl(url, **options)
    new(url).unfurl(**options)
  end

  def initialize(url, user: Current.user)
    @uri = URI.parse(url)
    @metadata = nil
    @user = user
  end

  def unfurl
    if unfurler&.setup?
      @metadata = unfurler.unfurl
    end

    self
  end

  def unfurler
    @unfurler ||= begin
      unfurler = UNFURLERS.find { |unfurler| unfurler.unfurls?(uri) }
      unfurler&.new(uri, user: user)
    end
  end
end
