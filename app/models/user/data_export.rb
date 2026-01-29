class User::DataExport < Export
  private
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
      add_file_to_zip(zip, "#{card.number}.json", card.export_json)

      card.export_attachments.each do |attachment|
        add_file_to_zip(zip, attachment[:path], compression_method: Zip::Entry::STORED) do |f|
          attachment[:blob].download { |chunk| f.write(chunk) }
        end
      rescue ActiveStorage::FileNotFoundError
        # Skip attachments where the file is missing from storage
      end
    end
end
