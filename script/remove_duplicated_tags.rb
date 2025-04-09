#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  Account.find_each do |account|
    tags_grouped_by_title = account.tags.group_by { |tag| tag.title.downcase }

    tags_grouped_by_title.each do |title, tags|
      if tags.length > 1
        to_keep, to_merge = tags.first, tags[1..]

        to_merge.each do |tag_to_merge|
          tag_to_merge.cards.each do |card|
            to_keep.cards << card unless to_keep.cards.include?(card)
          end

          tag_to_merge.destroy
        end
      end
    end
  end
end
