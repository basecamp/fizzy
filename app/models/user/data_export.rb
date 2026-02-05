class User::DataExport < Export
  private
    def filename
      "fizzy-user-data-export-#{id}.zip"
    end

    def populate_zip(zip)
      exportable_cards.find_each do |card|
        add_card_to_zip(zip, card)
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
      zip.add_file("#{card.number}.json", card.export_json)

      card.export_attachments.each do |attachment|
        zip.add_file(attachment[:path], compress: false) do |f|
          attachment[:blob].download { |chunk| f.write(chunk) }
        end
      rescue ActiveStorage::FileNotFoundError
        # Skip attachments where the file is missing from storage
      end
    end
end
