class Notification::MentionPayload < Notification::DefaultPayload
  include ExcerptHelper

  private
    def title
      "#{mention.mentioner.first_name} mentioned you"
    end

    def body
      format_excerpt(mention.source.mentionable_content, length: 200)
    end

    def url
      card_url(card)
    end

    def mention
      notification.source
    end
end
