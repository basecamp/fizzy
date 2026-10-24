# Fail fast on a SaaS deploy missing OAUTH_TOKEN_PEPPER (see TokenDigester).
# Asset precompilation boots with a dummy secret key base and no runtime
# secrets, and never digests anything.
Rails.application.config.after_initialize do
  TokenDigester.verify_pepper! unless ENV["SECRET_KEY_BASE_DUMMY"]
end
