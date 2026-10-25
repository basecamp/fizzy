# Routes whose path carries a credential (a join code, a publication key, a signed id) are drawn inside
# filter_path_parameters in config/routes.rb, so rails_structured_logging logs those segments as
# [FILTERED]. Without it, in OSS mode, there's no structured log to filter and the block just draws its
# routes. A method the gem includes later wins over this one, and an earlier one is left alone.
unless ActionDispatch::Routing::Mapper.method_defined?(:filter_path_parameters)
  ActionDispatch::Routing::Mapper.include(Module.new do
    def filter_path_parameters(*)
      yield
    end
  end)
end
