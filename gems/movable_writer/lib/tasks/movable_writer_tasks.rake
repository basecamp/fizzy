# frozen_string_literal: true

namespace :movable_writer do
  desc "Install Movable Writer"
  task :install do
    Rails::Command.invoke :generate, [ "movable_writer:install" ]
  end
end
