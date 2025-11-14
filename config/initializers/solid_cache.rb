Rails.application.configure do
  config.solid_cache.connects_to = { database: { writing: :cache, reading: :cache } }
end
