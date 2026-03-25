require_relative "lib/fizzy/version"

Gem::Specification.new do |spec|
  spec.name = "fizzy-cli"
  spec.version = Fizzy::VERSION
  spec.authors = ["OpenAI Codex"]
  spec.summary = "Standalone CLI for the Fizzy developer API"
  spec.description = "A standalone command-line interface for authenticating with Fizzy and performing CRUD operations against boards, cards, comments, and related resources."
  spec.files = Dir["exe/*", "lib/**/*.rb"]
  spec.bindir = "exe"
  spec.executables = ["fizzy"]
  spec.require_paths = ["lib"]
  spec.license = "MIT"
  spec.add_dependency "thor"
end
