module Fizzy
  def self.saas?
    return @saas if defined?(@saas)
    @saas = !!(ENV["SAAS"] || File.exist?(File.expand_path("../../tmp/saas.txt", __dir__)))
  end
end
