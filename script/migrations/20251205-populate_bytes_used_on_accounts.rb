#!/usr/bin/env ruby

require_relative "../../config/environment"

Account.find_each do |account|
  account.recalculate_bytes_used
  puts "#{account.id}: #{account.bytes_used} bytes"
end
