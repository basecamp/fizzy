#!/usr/bin/env ruby

require_relative "../config/environment"

def replace_url(string)
  string.gsub(%r{/buckets/(\d+)/bubbles/(\d+)}) do
    "/boards/#{$1}/cards/#{$2}"
  end
end

ApplicationRecord.with_each_tenant do |tenant|
  Account.find_each do |account|
    Comment.find_each do |comment|
      comment.update!(body: replace_url(comment.body.content.to_s))
    end
  end
end
