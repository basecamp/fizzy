module SmtpDeliveryErrorHandling
  extend ActiveSupport::Concern

  included do
    # Retry delivery to possibly-unavailable remote mailservers.
    retry_on Net::OpenTimeout, Net::ReadTimeout, Socket::ResolutionError, wait: :polynomially_longer

    # Net::SMTPServerBusy is SMTP error code 4xx, a temporary error.
    # Common one we've seen is 452 4.3.1 Insufficient system storage.
    # Patiently retry.
    retry_on Net::SMTPServerBusy, wait: :polynomially_longer

    # SMTP error 50x.
    rescue_from Net::SMTPSyntaxError do |error|
      case error.message
      when /\A501 5\.1\.3/
        # Ignore undeliverable email addresses.
        Sentry.capture_exception error, level: :info if Fizzy.saas?
      else
        raise
      end
    end

    # SMTP error 5xx except 50x and 53x.
    # * 550 5.1.1: Unknown users
    # * 552 5.6.0: Message/headers too large
    rescue_from Net::SMTPFatalError do |error|
      case error.message
      when /\A550 5\.1\.1/, /\A552 5\.6\.0/, /\A555 5\.5\.4/
        Sentry.capture_exception error, level: :info if Fizzy.saas?
      else
        raise
      end
    end
  end
end
