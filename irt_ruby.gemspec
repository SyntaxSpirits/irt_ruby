# frozen_string_literal: true

require_relative "lib/irt_ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "irt_ruby"
  spec.version       = IrtRuby::VERSION
  spec.authors       = ["Alex Kholodniak"]
  spec.email         = ["alexandrkholodniak@gmail.com"]

  spec.summary       = "Production-ready Item Response Theory (IRT) models with comprehensive performance benchmarking and adaptive optimization."
  spec.description   = <<~DESC
    IrtRuby is a comprehensive Ruby library for Item Response Theory (IRT) analysis,#{" "}
    commonly used in educational assessment, psychological testing, and survey research.

    Features three core IRT models:
    • Rasch Model (1PL) - Simple difficulty-only model
    • Two-Parameter Model (2PL) - Adds item discrimination
    • Three-Parameter Model (3PL) - Includes guessing parameter

    Key capabilities:
    • Robust gradient ascent optimization with adaptive learning rates
    • Flexible missing data strategies (ignore, treat as incorrect/correct)
    • Comprehensive performance benchmarking suite
    • Memory-efficient implementation with excellent scaling
    • Production-ready with extensive test coverage

    Perfect for researchers, data scientists, and developers working with#{" "}
    educational assessments, psychological measurements, or any binary response data
    where item and person parameters need to be estimated simultaneously.
  DESC

  spec.homepage      = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/SyntaxSpirits/irt_ruby"
  spec.metadata["changelog_uri"]   = "https://github.com/SyntaxSpirits/irt_ruby/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/SyntaxSpirits/irt_ruby#readme"
  spec.metadata["bug_tracker_uri"] = "https://github.com/SyntaxSpirits/irt_ruby/issues"

  spec.files = Dir["lib/**/*.rb", "benchmarks/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.required_ruby_version = ">= 2.6"

  spec.bindir      = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "matrix", "~> 0.4.2"

  spec.add_development_dependency "benchmark-ips", "~> 2.0"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "memory_profiler", "~> 1.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
