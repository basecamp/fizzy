class Notification::MentionPayload < Notification::DefaultPayload
  include ExcerptHelper

  def title
    "#{mention.mentioner.first_name} mentioned you"
  end

  def body
    format_excerpt(mention.source.mentionable_content, length: 200)
  end

  def url
    card_url(card)
  end

  private
    def mention
      notification.source
    end
end
