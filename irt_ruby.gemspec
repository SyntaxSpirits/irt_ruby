# frozen_string_literal: true

require_relative "lib/irt_ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "irt_ruby"
  spec.version       = IrtRuby::VERSION
  spec.authors       = ["Alex Kholodniak"]
  spec.email         = ["alexandrkholodniak@gmail.com"]

  spec.summary       = "A Ruby gem that provides Rasch, 2PL, and 3PL models for Item Response Theory (IRT), with flexible missing data strategies."
  spec.description   = <<~DESC
    IrtRuby provides implementations of the Rasch model, Two-Parameter model, 
    and Three-Parameter model for Item Response Theory (IRT). 
    It allows you to estimate the abilities of individuals and the difficulties, 
    discriminations, and guessing parameters of items based on their responses 
    to a set of items. This version adds support for multiple missing data 
    strategies (:ignore, :treat_as_incorrect, :treat_as_correct), expanded 
    test coverage, and improved adaptive optimization.
  DESC

  spec.homepage      = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"]   = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.metadata["changelog_uri"] = "https://github.com/SyntaxSpirits/irt_ruby/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb"]
  spec.required_ruby_version = ">= 2.6"

  spec.bindir      = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "matrix", "~> 0.4.2"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
