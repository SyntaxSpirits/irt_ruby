# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

# Benchmark tasks
namespace :benchmark do
  desc "Run performance benchmarks"
  task :performance do
    ruby "benchmarks/performance_benchmark.rb"
  end

  desc "Run convergence analysis benchmarks"
  task :convergence do
    ruby "benchmarks/convergence_benchmark.rb"
  end

  desc "Run all benchmarks"
  task all: [:performance, :convergence] do
    puts "All benchmarks completed!"
  end

  desc "Run quick benchmarks (reduced dataset sizes)"
  task :quick do
    puts "Running quick performance benchmark..."
    ENV['QUICK_BENCHMARK'] = '1'
    ruby "benchmarks/performance_benchmark.rb"
  end
end
