#!/usr/bin/env ruby

require_relative "../../config/environment"

cross_account_taggings = Tagging.joins(:tag).where("taggings.account_id != tags.account_id")

puts "Found #{cross_account_taggings.count} cross-account taggings to fix"

cross_account_taggings.find_each do |tagging|
  correct_tag = tagging.account.tags.find_or_create_by!(title: tagging.tag.title)
  tagging.update!(tag: correct_tag)
  puts "Fixed tagging #{tagging.id}: reassigned to tag #{correct_tag.id}"
end

puts "Done!"
