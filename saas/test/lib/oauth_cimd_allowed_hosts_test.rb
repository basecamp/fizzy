require "test_helper"
require "kamal"

# The tests exercise metadata documents against config/environments/test.rb's recognized hosts, and
# production recognizes the ones saas/config/deploy.yml passes it. Keep the two lists the same, so a
# host the tests connect through is one production connects through too.
class OauthCimdAllowedHostsTest < ActiveSupport::TestCase
  test "production recognizes the metadata document hosts the tests do" do
    assert_equal Rails.application.config.x.oauth.cimd_allowed_hosts, production_hosts
    assert_includes production_hosts, "www.perplexity.ai"
    assert_includes production_hosts, "platform.muse.ai"
  end

  private
    def production_hosts
      web = configuration.role(:web)
      web.env(web.hosts.first).clear.fetch("OAUTH_CIMD_ALLOWED_HOSTS").split
    end

    def configuration
      Kamal::Configuration.create_from \
        config_file: Rails.root.join("saas/config/deploy.yml"), destination: "production", version: "test"
    end
end
