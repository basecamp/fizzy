class Link::Metadata
  include ActionView::Helpers::SanitizeHelper

  attr_reader :title, :description, :image_url, :canonical_url,
              :unsafe_title, :unsafe_description, :unsafe_image_url, :unsafe_canonical_url

  def initialize(**attributes)
    @unsafe_canonical_url = attributes[:canonical_url]
    @canonical_url = sanitize_url(@unsafe_canonical_url)

    @unsafe_title = attributes[:title]
    @title = sanitize_text(@unsafe_title)

    @unsafe_description = attributes[:description]
    @description = sanitize_text(@unsafe_description)

    @unsafe_image_url = attributes[:image_url]
    @image_url = sanitize_url(absolute_uri(@unsafe_image_url, relative_to: @canonical_url))
  end

  private
    def sanitize_text(content)
      sanitize(strip_tags(content))
    end

    def sanitize_url(url, relative_to: nil)
      uri = URI.parse(url)

      if uri.is_a?(URI::HTTP) && uri.absolute?
        uri.to_s
      else
        nil
      end
    rescue URI::InvalidURIError
      nil
    end

    def absolute_uri(url, relative_to:)
      uri = URI.parse(url)

      if uri.absolute?
        uri
      else
        URI.parse(relative_to) + uri
      end
    rescue URI::InvalidURIError
      nil
    end
end
