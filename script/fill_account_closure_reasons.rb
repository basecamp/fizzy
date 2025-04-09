#!/usr/bin/env ruby

require_relative "../config/environment"

ApplicationRecord.with_each_tenant do |tenant|
  Account.find_each do |account|
    account.send(:create_default_closure_reasons)
  end
end
