class Account::Export < ApplicationRecord
  belongs_to :account
  belongs_to :user

  has_one_attached :file

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending

  scope :current, -> { where(created_at: 24.hours.ago..) }
  scope :expired, -> { where(completed_at: ...24.hours.ago) }

  def self.cleanup
    expired.destroy_all
  end

  def build_later
    ExportAccountDataJob.perform_later(self)
  end

  def build
    processing!
    zipfile = generate_zip

    file.attach io: File.open(zipfile.path), filename: "fizzy-export-#{id}.zip", content_type: "application/zip"
    mark_completed

    ExportMailer.completed(self).deliver_later
  rescue => e
    update!(status: :failed)
    raise
  ensure
    zipfile&.close
    zipfile&.unlink
  end

  def mark_completed
    update!(status: :completed, completed_at: Time.current)
  end

  private
    def generate_zip
      Tempfile.new([ "export", ".zip" ]).tap do |tempfile|
        Zip::File.open(tempfile.path, create: true) do |zip|
          exportable_cards.find_each do |card|
            add_card_to_zip(zip, card)
          end
        end
      end
    end

    def exportable_cards
      user.accessible_cards.includes(
        :board,
        creator: :identity,
        comments: { creator: :identity },
        rich_text_description: { embeds_attachments: :blob }
      )
    end

    def add_card_to_zip(zip, card)
      zip.get_output_stream("#{card.number}.json") do |f|
        f.write(card.export_json)
      end

      card.export_attachments.each do |attachment|
        zip.get_output_stream(attachment[:path], compression_method: Zip::Entry::STORED) do |f|
          attachment[:blob].download { |chunk| f.write(chunk) }
        end
      rescue ActiveStorage::FileNotFoundError
        # Skip attachments where the file is missing from storage
      end
    end
end
