require "test_helper"
require "rake"

class OauthProvisionFirstPartyClientsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("oauth:provision_first_party_clients")
    Rake::Task["oauth:provision_first_party_clients"].reenable

    @saved_resources = Rails.application.config.x.oauth.mcp_resources
    Rails.application.config.x.oauth.mcp_resources = [ "https://mcp.fizzy.do/mcp" ]
    @saved_dry_run = ENV.delete("DRY_RUN")
  end

  teardown do
    Rails.application.config.x.oauth.mcp_resources = @saved_resources
    ENV["DRY_RUN"] = @saved_dry_run
  end

  test "names each client it converges, and each one still awaiting a secret" do
    output, _ = capture_io { Rake::Task["oauth:provision_first_party_clients"].invoke }

    assert_match "fizzy-personal-access: converged", output
    assert_match "fizzy-mcp-server: created", output
    assert_match %(oauth:mint_client_secret[fizzy-mcp-server]), output
    assert_no_match %(oauth:mint_client_secret[fizzy-personal-access]), output
  end

  test "a dry run prints each client's changes and writes nothing" do
    Oauth::Client.personal_access.update_all trusted: false
    ENV["DRY_RUN"] = "1"

    output, _ = assert_no_changes -> { Oauth::Client.order(:client_id).map(&:attributes) } do
      capture_io { Rake::Task["oauth:provision_first_party_clients"].invoke }
    end

    assert_match "Dry run: nothing is written.", output
    assert_match "fizzy-personal-access: would converge\n  trusted: false -> true", output
    assert_match "fizzy-mcp-server: would be created", output
    assert_match %(  protected_resource: nil -> "https://mcp.fizzy.do/mcp"), output
    assert_match "fizzy-mcp-server would have no secret yet", output
    assert_not Oauth::Client.exists?(client_id: "fizzy-mcp-server")
  end

  test "a dry run of a converged install changes nothing" do
    Oauth::FirstPartyClients.provision!
    ENV["DRY_RUN"] = "1"

    output, _ = capture_io { Rake::Task["oauth:provision_first_party_clients"].invoke }

    assert_match "fizzy-personal-access: unchanged", output
    assert_match "fizzy-mcp-server: unchanged", output
    assert_no_match " -> ", output
  end

  test "DRY_RUN=0 converges" do
    ENV["DRY_RUN"] = "0"

    output, _ = capture_io { Rake::Task["oauth:provision_first_party_clients"].invoke }

    assert_match "fizzy-mcp-server: created", output
    assert Oauth::Client.exists?(client_id: "fizzy-mcp-server")
  end
end
