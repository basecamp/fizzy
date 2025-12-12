module HtmlHelper
  include ERB::Util

  EXCLUDE_PUNCTUATION = %(.?,:!;"'<>)
  EXCLUDE_PUNCTUATION_REGEX = /[#{Regexp.escape(EXCLUDE_PUNCTUATION)}]+\z/

  def format_html(html)
    fragment = Nokogiri::HTML5.fragment(html)

    auto_link(fragment)

    fragment.to_html.html_safe
  end

  private
    EXCLUDED_ELEMENTS = %w[ a figcaption pre code ]
    EMAIL_AUTOLINK_REGEXP = /\b[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\b/
    URL_REGEXP = URI::DEFAULT_PARSER.make_regexp(%w[http https])

    def auto_link(fragment)
      fragment.traverse do |node|
        next unless auto_linkable_node?(node)

        # Take care to escape the html text node, so that the subsequent Nokogiri re-parse doesn't
        # create tags where there aren't any.
        content = h(node.text)
        linked_content = content.dup

        auto_link_urls(linked_content)
        auto_link_emails(linked_content)

        if linked_content != content
          node.replace(Nokogiri::HTML5.fragment(linked_content))
        end
      end
    end

    def auto_linkable_node?(node)
      node.text? && node.ancestors.none? { |ancestor| EXCLUDED_ELEMENTS.include?(ancestor.name) }
    end

    def auto_link_urls(linked_content)
      linked_content.gsub!(URL_REGEXP) do |match|
        url, trailing_punct = extract_url_and_punctuation(match)
        %(<a href="#{url}" rel="noreferrer">#{url}</a>#{trailing_punct})
      end
    end

    def extract_url_and_punctuation(url_match)
      url_match = CGI.unescapeHTML(url_match)
      if match = url_match.match(EXCLUDE_PUNCTUATION_REGEX)
        len = match[0].length
        [ url_match[..-(len+1)], url_match[-len..] ]
      else
        [ url_match, "" ]
      end
    end

    def auto_link_emails(text)
      text.gsub!(EMAIL_AUTOLINK_REGEXP) do |match|
        %(<a href="mailto:#{match}">#{match}</a>)
      end
    end
end
