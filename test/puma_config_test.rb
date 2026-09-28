require "test_helper"
require "puma/configuration"

class PumaConfigTest < ActiveSupport::TestCase
  test "no local environment runs Solid Queue inside Puma" do
    %w[ development test ].each do |env|
      plugins = puma_plugins_for(env)

      assert_includes plugins, :tmp_restart, "#{env}: this probe found no plugins at all"
      assert_not_includes plugins, :solid_queue, "#{env}: Puma would fork a supervisor with no queue database to serve it"
    end
  end

  private
    KNOWN_PLUGINS = %i[ tmp_restart solid_queue ]

    def puma_plugins_for(env)
      with_rails_env(env) do
        config = Puma::Configuration.new({}, config_files: [ Rails.root.join("config/puma.rb").to_s ])
        config.load

        instances = config.plugins.instance_variable_get(:@instances)
        KNOWN_PLUGINS.select { |name| instances.any? { |plugin| plugin.is_a?(Puma::Plugins.find(name)) } }
      end
    end

    def with_rails_env(env)
      original = Rails.env
      Rails.env = env
      yield
    ensure
      Rails.env = original
    end
end
