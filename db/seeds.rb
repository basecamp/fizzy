# Running `rails db:seed` will run `db:fixtures:load` in development.

seed_path = Rails.root.join("db", "seeds", "#{Rails.env}.rb")
require seed_path if File.exist?(seed_path)

