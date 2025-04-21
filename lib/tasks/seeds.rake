namespace :db do
  Rake::Task["seed"].enhance [ "db:load_fixtures_in_development" ]

  task :load_fixtures_in_development do
    if Rails.env.development?
      Rake::Task["db:fixtures:load"].invoke
      [ Card, Comment ].each(&:reindex_all)
    end
  end
end
