class EmailDeliveryLogger
  def self.delivered_email(message)
    Rails.logger.info(
      "[EmailDelivery] To: #{message.to.join(", ")} | " \
      "Subject: #{message.subject} | " \
      "Date: #{Time.current}"
    )
  end
end

ActionMailer::Base.register_observer(EmailDeliveryLogger)

