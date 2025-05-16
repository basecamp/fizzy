RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.openai_api_key || ENV["OPEN_AI_API_KEY"]
  config.default_model = "gpt-4.1-nano"
end
