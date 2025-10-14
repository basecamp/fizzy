module Bootstrap
  def self.oss_config?
    ENV.fetch("OSS_CONFIG", "") != "" || !File.directory?(File.expand_path("../gems/fizzy-saas", __dir__))
  end
end
