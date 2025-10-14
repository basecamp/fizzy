# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit",       "bin/bundler-audit check --update"
  step "Security: Importmap audit", "bin/importmap audit"
  step "Security: Brakeman audit",  "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: Rails: SaaS config", "bin/rails test"
  step "Tests: Rails: OSS config",  "OSS_CONFIG=1 bin/rails test"
  step "Tests: System",             "bin/rails test:system"

  if success?
    step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
