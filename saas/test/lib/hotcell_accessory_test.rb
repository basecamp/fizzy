require "test_helper"
require "erb"
require "kamal"

# Asserted against the `docker run` Kamal generates rather than the YAML, because Kamal contributes flags
# of its own — a setting can be present in the file and reach the daemon twice, which is a
# `docker: conflicting options` from a file that reads correctly. Every destination, because destination
# files deep-merge into the base and arrays are replaced rather than merged.
class HotcellAccessoryTest < ActiveSupport::TestCase
  # `beta` is the shared template the numbered betas render; it raises without BETA_NUMBER.
  DESTINATIONS = Dir[Rails.root.join("saas/config/deploy.*.yml")]
    .map { File.basename(it, ".yml").delete_prefix("deploy.") } - %w[ beta ]

  test "the cell has exactly one network, and it is none" do
    each_destination do |command|
      assert_equal 1, command.scan(/--network\b/).size, "Kamal supplies one of its own"
      assert_match(/--network "?none"?/, command)
    end
  end

  test "the cell has no capabilities and a read-only root" do
    each_destination do |command|
      assert_match "--read-only", command
      assert_equal "ALL", flag(command, "--cap-drop")
      assert_equal "no-new-privileges:true", flag(command, "--security-opt")
      assert_equal "10001:10001", flag(command, "--user")
      assert_equal "512", flag(command, "--pids-limit")
    end
  end

  # The size cap and the nosuid,nodev,noexec flags ride the host mount, which app_kamal's chef recipe
  # owns; from here only the mount itself is visible.
  test "scratch is the provisioned loopback filesystem" do
    each_destination do |command|
      assert_match "--volume /var/lib/hotcell-scratch:/tmp", command
      assert_no_match(/--tmpfs/, command)
    end
  end

  test "memory-swap matches memory, or the memory limit stops holding" do
    each_destination do |command|
      assert_equal flag(command, "--memory"), flag(command, "--memory-swap")
    end
  end

  # Scratch no longer lives in the cgroup, so memory holds only processes.
  test "the cgroup stays above the cell's own rlimit, so a breach is a verdict rather than a SIGKILL" do
    each_destination do |command|
      assert_operator megabytes(flag(command, "--memory")), :>, cell_memory_megabytes
    end
  end

  test "the cell lands on the hosts that call it" do
    assert_equal [ "web", "jobs" ], accessory["roles"]
  end

  # Three numbers in three places that must agree, and nothing else checks them. Any one alone is a cell
  # that answers echo and fails every operation that hands a tool a filename.
  test "the app shares the cell's group, and is told the same number" do
    DESTINATIONS.each do |destination|
      cell_gid = flag(run_command(destination), "--user")[/:(\d+)\z/, 1]

      configuration(destination).roles.each do |role|
        assert_equal cell_gid, role.option_args.join(" ")[/--group-add "(\d+)"/, 1],
          "#{destination} #{role.name} group-add"
        assert_equal cell_gid, role.env(role.hosts.first).clear["HOTCELL_GROUP"].to_s,
          "#{destination} #{role.name} HOTCELL_GROUP"
      end
    end
  end

  test "the image tag is immutable" do
    assert_no_match(/:latest$/, accessory["image"])
  end

  # The tag is a hash of exactly what the image is built from, so the two can only agree if the pin moved
  # with the contents. Nothing else notices a stale pin; this shipped once already.
  test "the pinned image is the one this tree builds" do
    built = `bash -c "source #{Rails.root}/saas/hotcell/bin/image && hotcell_image_tag #{Rails.root}"`.strip.split(":").last

    assert_equal built, accessory["image"][/:([^:]+)\z/, 1],
      "saas/hotcell's contents changed since the accessory was pinned — run saas/hotcell/bin/build and re-pin"
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
    def each_destination
      DESTINATIONS.each do |destination|
        yield run_command(destination)
      rescue Minitest::Assertion => error
        raise error.class, "#{destination}: #{error.message}"
      end
    end

    def run_command(destination)
      Kamal::Commands::Accessory.new(configuration(destination), name: :hotcell).run.flatten.join(" ")
    end

    def configuration(destination)
      @configurations ||= {}
      @configurations[destination] ||= Kamal::Configuration.create_from(
        config_file: Rails.root.join("saas/config/deploy.yml"), destination: destination, version: "test")
    end

    # Kamal quotes what it argumentizes, so a flag's value ends at the closing quote.
    def flag(command, name)
      command[/#{Regexp.escape(name)} "([^"]+)"/, 1]
    end

    def deploy_configuration
      @deploy_configuration ||= YAML.load(ERB.new(Rails.root.join("saas/config/deploy.yml").read).result)
    end

    def accessory
      deploy_configuration.dig("accessories", "hotcell")
    end

    def socket_volume
      accessory["volumes"].first.split(":").first
    end

    def cell_configuration
      @cell_configuration ||= Rails.root.join("saas/hotcell/config.rb").read
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
