class Link::OpenGraphUnfurler
  attr_reader :uri, :user

  def self.unfurls?(uri)
    uri.is_a?(URI::HTTP)
  end

  def initialize(uri, user: nil, **options)
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
    fetch = Link::Fetch.new(uri)

    if fetch.http_url? && fetch.html_content?
      content = fetch.content
      document = Nokogiri::HTML5(content)
      Link::Metadata.new(**extract_metadata_from_document(document))
    end
  end

  private
    def extract_metadata_from_document(document)
      Hash.new.tap do |metadata|
        metadata[:canonical_url] = extract_canonical_url_from_document(document) || uri.to_s
        metadata[:title] = extract_title_from_document(document)
        metadata[:description] = extract_description_from_document(document)
        metadata[:image_url] = extract_image_url_from_document(document)
      end
    end

    def extract_canonical_url_from_document(document)
      document.at_css('meta[property="og:url"]')&.get_attribute("content") ||
        document.at_css('link[rel="canonical"]')&.get_attribute("href")
    end

    def extract_title_from_document(document)
      document.at_css('meta[property="og:title"]')&.get_attribute("content") ||
        document.at_css('meta[name="twitter:title"]')&.get_attribute("content") ||
        document.at_css("title")&.text&.strip
    end

    def extract_description_from_document(document)
      document.at_css('meta[property="og:description"]')&.get_attribute("content") ||
        document.at_css('meta[name="twitter:description"]')&.get_attribute("content") ||
        document.at_css('meta[name="description"]')&.get_attribute("content")
    end

    def extract_image_url_from_document(document)
      document.at_css('meta[property="og:image"]')&.get_attribute("content") ||
        document.at_css('meta[name="twitter:image"]')&.get_attribute("content")
    end
end
