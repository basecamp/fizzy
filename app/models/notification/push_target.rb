class Notification::PushTarget
  attr_reader :notification

  delegate :card, to: :notification

  def self.process(notification)
    new(notification).process
  end

  def initialize(notification)
    @notification = notification
  end

  def process
    raise NotImplementedError
  end
end
