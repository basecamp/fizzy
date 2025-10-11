#!/usr/bin/env ruby

require_relative "../../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  puts "✅ #{tenant}"
  Account.sole.setup_complete!
end
