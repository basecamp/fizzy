# rbs_inline: enabled

class QrCodeLink
  attr_reader :url #: String

  class << self
    def from_signed(signed)
      new verifier.verify(signed, purpose: :qr_code)
    end

    #: -> ActiveSupport::MessageVerifier
    def verifier
      ActiveSupport::MessageVerifier.new(secret, url_safe: true)
    end

    private
      #: -> String
      def secret
        Rails.application.key_generator.generate_key("qr_codes")
      end
  end

  #: (String) -> void
  def initialize(url)
    @url = url
  end

  def signed
    self.class.verifier.generate(@url, purpose: :qr_code)
  end
end
