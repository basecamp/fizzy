require "test_helper"
require "erb"

# Renders saas/config/database.yml the way config/database.yml does, under a stubbed Rails.root,
# Rails.env and FIZZY_DB_PORT, so each case reads the ports the app would connect to.
class DatabaseConfigTest < ActiveSupport::TestCase
  CONFIG = Rails.root.join("saas/config/database.yml")

  test "a git worktree with FIZZY_DB_PORT unset refuses to load in development and test" do
    %w[ development test ].each do |env|
      in_checkout(worktree: true) do |root|
        error = assert_raises(RuntimeError) { render(root:, env:, port: nil) }
        assert_match "FIZZY_DB_PORT is not set in this git worktree", error.message
      end
    end
  end

  test "a git worktree with FIZZY_DB_PORT set connects to that port" do
    in_checkout(worktree: true) do |root|
      assert_equal [ 33460 ], local_ports(render(root:, env: "test", port: "33460"))
    end
  end

  test "a worktree may share docker-dev's databases by naming 33384" do
    in_checkout(worktree: true) do |root|
      assert_equal [ 33384 ], local_ports(render(root:, env: "development", port: "33384"))
    end
  end

  test "the main checkout keeps docker-dev's default with FIZZY_DB_PORT unset" do
    in_checkout(worktree: false) do |root|
      assert_equal [ 33384 ], local_ports(render(root:, env: "test", port: nil))
    end
  end

  test "deployed environments never consult the worktree check" do
    %w[ production staging beta ].each do |env|
      in_checkout(worktree: true) do |root|
        assert_nothing_raised { render(root:, env:, port: nil) }
      end
    end
  end

  private
    def in_checkout(worktree:)
      Dir.mktmpdir do |dir|
        root = Pathname(dir)
        worktree ? root.join(".git").write("gitdir: /elsewhere/.git/worktrees/x\n") : root.join(".git").mkpath
        yield root
      end
    end

    def render(root:, env:, port:)
      Rails.stubs(:root).returns(root)
      Rails.stubs(:env).returns(ActiveSupport::EnvironmentInquirer.new(env))
      previous = ENV["FIZZY_DB_PORT"]
      port.nil? ? ENV.delete("FIZZY_DB_PORT") : ENV["FIZZY_DB_PORT"] = port
      YAML.safe_load(ERB.new(CONFIG.read).result, aliases: true)
    ensure
      previous.nil? ? ENV.delete("FIZZY_DB_PORT") : ENV["FIZZY_DB_PORT"] = previous
      Rails.unstub(:root)
      Rails.unstub(:env)
    end

    def local_ports(config)
      config.values_at("development", "test").flat_map { it.values }.map { it["port"] }.uniq
    end
end
