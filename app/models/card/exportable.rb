module Card::Exportable
  extend ActiveSupport::Concern
  include ActionView::Helpers::TagHelper

  def export_json
    JSON.pretty_generate({
      number: number,
      title: title,
      board: board.name,
      status: export_status,
      creator: export_user(creator),
      description: export_html(description),
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601,
      comments: comments.chronologically.map do |comment|
        {
          id: comment.id,
          body: export_html(comment.body),
          creator: export_user(comment.creator),
          created_at: comment.created_at.iso8601
        }
      end
    })
  end

  def export_attachments
    collect_attachments.map do |attachment|
      { path: export_attachment_path(attachment.blob), blob: attachment.blob }
    end
  end

  private
    def export_html(rich_text)
      return "" if rich_text.blank?

      rich_text.body.render_attachments do |attachment|
        attachment_representation(attachment)
      end.to_html
    end

    def attachment_representation(attachment)
      case attachable = attachment.attachable
      when ActiveStorage::Blob
        path = export_attachment_path(attachable)
        if attachable.image?
          tag.img(src: path, alt: attachable.filename)
        else
          tag.a(attachable.filename, href: path)
        end
      when ActionText::Attachables::RemoteImage
        tag.img(src: attachable.url, alt: "Remote image")
      else
        attachment.to_html
      end
    end

    def export_user(user)
      {
        id: user.id,
        name: user.name,
        email: user.identity&.email_address
      }
    end

    def export_attachment_path(blob)
      "#{number}/#{blob.key}_#{blob.filename}"
    end

    def collect_attachments
      (attachments.to_a + comments.flat_map { |c| c.attachments.to_a }).uniq(&:blob_id)
    end

    def export_status
      case
      when closed?
        "Done"
      when postponed?
        "Not now"
      when column.present?
        column.name
      else
        "Maybe?"
      end
    end
end
