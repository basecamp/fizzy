require "test_helper"
require "erb"

# Every one of these flags is what makes a cell a cell. Omit one and the protection is gone while the
# cell goes on serving requests exactly as before, so nothing else would notice.
class HotcellAccessoryTest < ActiveSupport::TestCase
  test "the cell has no network, no capabilities, and a read-only root" do
    assert_equal "none", options["network"]
    assert_equal true, options["read-only"]
    assert_equal "ALL", options["cap-drop"]
    assert_equal "no-new-privileges:true", options["security-opt"]
    assert_equal "10001:10001", options["user"]
  end

  test "scratch is not executable" do
    assert_match(/\bnoexec\b/, options["tmpfs"])
    assert_match(/\bnosuid\b/, options["tmpfs"])
    assert_match(/\bnodev\b/, options["tmpfs"])
  end

  test "memory-swap matches memory, or the memory limit stops holding" do
    assert_equal options["memory"], options["memory-swap"]
  end

  test "concurrent workers filling scratch cannot outgrow the tmpfs" do
    assert_operator megabytes(options["tmpfs"][/size=(\S+)/, 1]), :>=, concurrency * file_size_megabytes
  end

  test "the cgroup stays above the cell's own rlimit, so a breach is a verdict rather than a SIGKILL" do
    assert_operator megabytes(options["memory"]), :>, cell_memory_megabytes + megabytes(options["tmpfs"][/size=(\S+)/, 1])
  end

  test "the cell lands on the hosts that call it" do
    assert_equal [ "web", "jobs" ], accessory["roles"]
  end

  test "the image tag is immutable" do
    assert_no_match(/:latest$/, accessory["image"])
  end

  test "the app mounts the same volume the cell writes its sockets to" do
    app_mount = deploy_configuration["volumes"].find { it.start_with?("#{socket_volume}:") }

    assert_equal "#{socket_volume}:/run/hotcell/#{Fizzy::Saas::Cell::NAME}", app_mount
    assert_equal "/run/hotcell", deploy_configuration.dig("env", "clear", "HOTCELL_ROOT")
  end

  test "the app image creates the mount point owned by the cell's user" do
    assert_match %r{mkdir -p /run/hotcell/#{Fizzy::Saas::Cell::NAME}.*chown -R 10001:10001 /run/hotcell}m,
      Rails.root.join("saas/Dockerfile").read
  end

  private
    def deploy_configuration
      @deploy_configuration ||= YAML.load(ERB.new(Rails.root.join("saas/config/deploy.yml").read).result)
    end

    def accessory
      deploy_configuration.dig("accessories", "hotcell")
    end

    def options
      accessory["options"]
    end

    def socket_volume
      accessory["volumes"].first.split(":").first
    end

    def cell_configuration
      @cell_configuration ||= Rails.root.join("saas/hotcell/config.rb").read
    end

    def concurrency
      cell_configuration[/concurrency:\s*(\d+)/, 1].to_i
    end

    def file_size_megabytes
      cell_configuration[/file_size:\s*(\d+) \* 1024\*\*2/, 1].to_i
    end

    def cell_memory_megabytes
      cell_configuration[/memory:\s*(\d+) \* 1024\*\*2/, 1].to_i
    end

    def megabytes(size)
      case size
      when /\A(\d+)g\z/i then $1.to_i * 1024
      when /\A(\d+)m\z/i then $1.to_i
      else raise ArgumentError, "cannot read #{size.inspect} as a size"
      end
    end
end
