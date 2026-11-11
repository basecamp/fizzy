require "test_helper"
require "erb"
require "kamal"

# Production's secrets reach a container through three lists that nothing else keeps in step:
# the env.secret names in deploy.production.yml, the assignments in .kamal/secrets.production,
# and the names that file's one `kamal secrets fetch` asks for. A name missing from the first
# leaves the app reading nil; one missing from either of the others fails the deploy.
class ProductionSecretsTest < ActiveSupport::TestCase
  SECRETS_FILE = Rails.root.join("saas/.kamal/secrets.production")

  test "production delivers every variable reviewer sign-in reads" do
    %w[ FIZZY_REVIEWER_SIGN_IN_EMAIL FIZZY_REVIEWER_SIGN_IN_CODE_DIGEST FIZZY_REVIEWER_SIGN_IN_CODES ].each do |name|
      assert_includes web_secret_keys, name
    end
  end

  test "every secret production's containers read is assigned, and every extracted one is fetched" do
    secret_keys.each do |key|
      assert assignments.key?(key), "#{key} isn't assigned in #{SECRETS_FILE.basename}"

      if extracted = assignments[key][/\A\$\(kamal secrets extract (\S+) \$SECRETS\)\z/, 1]
        assert_includes fetched, extracted, "#{key} is extracted but not fetched"
      end
    end
  end

  private
    def web_secret_keys
      configuration.role(:web).env(configuration.role(:web).hosts.first).secret_keys
    end

    def secret_keys
      roles = configuration.roles.flat_map { |role| role.env(role.hosts.first).secret_keys }
      accessories = configuration.accessories.flat_map { |accessory| accessory.env.secret_keys }

      (roles + accessories).map { it.split(":", 2).last }.uniq
    end

    def assignments
      @assignments ||= SECRETS_FILE.readlines(chomp: true).filter_map { it.match(/\A(\w+)=(.*)\z/)&.captures }.to_h
    end

    # The fetched names, without the section each is read from.
    def fetched
      assignments.fetch("SECRETS").split(" --from ").last.split.drop(1).map { it.split("/").last.delete_suffix(")") }
    end

    def configuration
      @configuration ||= Kamal::Configuration.create_from(
        config_file: Rails.root.join("saas/config/deploy.yml"), destination: "production", version: "test")
    end
end
