class Link::FizzyUnfurler
  class << self
    def unfurls?(uri)
      uri.host == fizzy_host && uri.port == fizzy_port
    rescue URI::InvalidURIError
      false
    end

    private
      def fizzy_host
        url_options[:host]
      end

      def fizzy_port
        url_options[:port]
      end

      def url_options
        Rails.application.config.action_mailer.default_url_options
      end
  end

  attr_reader :uri, :user

  def initialize(uri, user:, **)
    @uri = uri
    @user = user
  end

  def requires_setup?
    false
  end

  def setup_config
    nil
  end

  def unfurl
    tenant, path = extract_tenant_from_path(uri.path)

    if tenant == ApplicationRecord.current_tenant
      target = Rails.application.routes.recognize_path(path) rescue {}

      case target
      in { controller: "cards", action: "show", id: id } then unfurl_card(id)
      else nil
      end
    end
  end

  private
    def extract_tenant_from_path(path)
      parts = path.match(%r{\A/(?<tenant>\d+)(?<path>.+)\Z})

      [ parts[:tenant], parts[:path] ]
    end

    def unfurl_card(id)
      card = user.accessible_cards.find_by(id: id)

      if card
        Link::Metadata.new(title: card.title, canonical_url: uri.to_s)
      end
    end
end
