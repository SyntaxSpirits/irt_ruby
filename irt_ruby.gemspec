# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "irt_ruby"
  spec.version       = "0.1.0"
  spec.authors       = ["Alex Kholodniak"]
  spec.email         = ["alexandrkholodniak@gmail.com"]

  spec.summary       = "A Ruby gem that provides implementations of Rasch, Two-Parameter, and Three-Parameter models for Item Response Theory (IRT)."
  spec.description   = "IrtRuby is a Ruby gem that provides implementations of the Rasch model, Two-Parameter model, and Three-Parameter model for Item Response Theory (IRT). It allows you to estimate the abilities of individuals and the difficulties, discriminations, and guessing parameters of items based on their responses to a set of items."
  spec.homepage      = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.metadata["changelog_uri"] = "https://github.com/SyntaxSpirits/irt_ruby/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb"]
  spec.required_ruby_version = ">= 2.6"

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
