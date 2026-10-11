# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

# Exact pin: NewCops is enabled, so any RuboCop release can add offenses.
# This version needs Ruby >= 2.7; the Ruby 2.6 CI job only runs the specs.
gem "rubocop", "1.92.0", require: false if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7")

# Performance benchmarking
gem "benchmark-ips", "~> 2.0"
gem "memory_profiler", "~> 1.0"
