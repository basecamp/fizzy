require "fileutils"
require "yaml"

module Fizzy
  class ConfigStore
    DEFAULT_PATH = File.expand_path("~/.config/fizzy/config.yml")

    attr_reader :path

    def initialize(path: ENV["FIZZY_CONFIG"] || DEFAULT_PATH)
      @path = path
    end

    def load
      return { "profiles" => {} } unless File.exist?(path)

      YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || { "profiles" => {} }
    end

    def save_profile(name, attributes, set_current: true)
      data = load
      data["profiles"] ||= {}
      data["profiles"][name] = attributes
      data["current_profile"] = name if set_current
      persist(data)
    end

    def set_current_profile(name)
      data = load
      raise Error, "Unknown profile #{name}" unless data.fetch("profiles", {}).key?(name)

      data["current_profile"] = name
      persist(data)
    end

    def current_profile_name
      ENV["FIZZY_PROFILE"] || load["current_profile"]
    end

    def profile(name = current_profile_name)
      return unless name

      load.fetch("profiles", {})[name]
    end

    def profiles
      load.fetch("profiles", {})
    end

    private
      def persist(data)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, YAML.dump(data))
        File.chmod(0o600, path)
        data
      end
  end
end
