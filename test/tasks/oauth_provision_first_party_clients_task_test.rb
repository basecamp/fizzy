require "test_helper"
require "rake"

class OauthProvisionFirstPartyClientsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("oauth:provision_first_party_clients")
    Rake::Task["oauth:provision_first_party_clients"].reenable

    @saved_resources = Rails.application.config.x.oauth.mcp_resources
    Rails.application.config.x.oauth.mcp_resources = [ "https://mcp.fizzy.do/mcp" ]
  end

  teardown do
    Rails.application.config.x.oauth.mcp_resources = @saved_resources
  end

  test "names each client it converges, and each one still awaiting a secret" do
    output, _ = capture_io { Rake::Task["oauth:provision_first_party_clients"].invoke }

    assert_match "fizzy-personal-access: converged", output
    assert_match "fizzy-mcp-server: created", output
    assert_match %(oauth:mint_client_secret[fizzy-mcp-server]), output
    assert_no_match %(oauth:mint_client_secret[fizzy-personal-access]), output
  end
end
