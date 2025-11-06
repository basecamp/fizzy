#!/usr/bin/env ruby

require_relative "../config/environment"

def replace_url(string)
  string.gsub(%r{/boards/\d+/cards/(\d+)}) do
    "/cards/#{$1}"
  end
end

def fix_rich_text(rich_text)
  original_html = rich_text.body_before_type_cast
  new_html = replace_url(original_html)
  if original_html != new_html
    rich_text.update_columns(body: new_html)
  end
end

ApplicationRecord.with_each_tenant do
  ActionText::RichText.where(record_type: "Card", name: "description").find_each do |rich_text|
    fix_rich_text rich_text
  end

  ActionText::RichText.where(record_type: "Comment", name: "body").find_each do |rich_text|
    fix_rich_text rich_text
  end
end
