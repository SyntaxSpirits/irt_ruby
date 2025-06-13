#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "irt_ruby"
require "benchmark/ips"
require "memory_profiler"

# Generate test data of different sizes
def generate_data(num_people, num_items, missing_rate: 0.0)
  Array.new(num_people) do
    Array.new(num_items) do
      if rand < missing_rate
        nil
      else
        rand < 0.6 ? 1 : 0 # 60% probability of correct response
      end
    end
  end
end

# Dataset configurations
DATASET_CONFIGS = [
  { people: 10, items: 5, label: "Tiny (10x5)" },
  { people: 50, items: 20, label: "Small (50x20)" },
  { people: 100, items: 50, label: "Medium (100x50)" },
  { people: 200, items: 100, label: "Large (200x100)" },
  { people: 500, items: 200, label: "XLarge (500x200)" }
].freeze

puts "=" * 60
puts "IRT Ruby Performance Benchmarks"
puts "=" * 60
puts

# Benchmark each model type across different dataset sizes
DATASET_CONFIGS.each do |config|
  puts "Dataset: #{config[:label]}"
  puts "-" * 40

  data = generate_data(config[:people], config[:items])

  Benchmark.ips do |x|
    x.config(time: 5, warmup: 2)

    x.report("Rasch Model") do
      model = IrtRuby::RaschModel.new(data, max_iter: 100)
      model.fit
    end

    x.report("2PL Model") do
      model = IrtRuby::TwoParameterModel.new(data, max_iter: 100)
      model.fit
    end

    x.report("3PL Model") do
      model = IrtRuby::ThreeParameterModel.new(data, max_iter: 100)
      model.fit
    end

    x.compare!
  end

  puts
end

# Memory usage analysis for medium dataset
puts "=" * 60
puts "Memory Usage Analysis (Medium Dataset: 100x50)"
puts "=" * 60

data = generate_data(100, 50)

%i[RaschModel TwoParameterModel ThreeParameterModel].each do |model_class|
  puts "\n#{model_class}:"
  puts "-" * 20

  report = MemoryProfiler.report do
    model = IrtRuby.const_get(model_class).new(data, max_iter: 100)
    model.fit
  end

  puts "Total allocated: #{report.total_allocated_memsize} bytes"
  puts "Total retained:  #{report.total_retained_memsize} bytes"
  puts "Objects allocated: #{report.total_allocated}"
  puts "Objects retained:  #{report.total_retained}"
end

# Scaling analysis - how performance changes with dataset size
puts "\n#{"=" * 60}"
puts "Scaling Analysis - Rasch Model Only"
puts "=" * 60

scaling_results = {}

DATASET_CONFIGS.each do |config|
  data = generate_data(config[:people], config[:items])

  times = []
  5.times do
    start_time = Time.now
    model = IrtRuby::RaschModel.new(data, max_iter: 100)
    model.fit
    end_time = Time.now
    times << (end_time - start_time)
  end

  avg_time = times.sum / times.size
  scaling_results[config[:label]] = {
    size: config[:people] * config[:items],
    avg_time: avg_time,
    people: config[:people],
    items: config[:items]
  }

  puts "#{config[:label]}: #{avg_time.round(4)}s (#{config[:people] * config[:items]} data points)"
end

# Calculate scaling coefficient
puts "\nScaling Analysis:"
puts "-" * 20
scaling_results.each_cons(2) do |(label1, data1), (label2, data2)|
  size_ratio = data2[:size].to_f / data1[:size]
  time_ratio = data2[:avg_time] / data1[:avg_time]
  scaling_factor = Math.log(time_ratio) / Math.log(size_ratio)

  puts "#{label1} -> #{label2}: #{size_ratio.round(2)}x size, #{time_ratio.round(2)}x time (O(n^#{scaling_factor.round(2)}))"
end

# Missing data performance impact
puts "\n#{"=" * 60}"
puts "Missing Data Strategy Performance Impact"
puts "=" * 60

data_with_missing = generate_data(100, 50, missing_rate: 0.2)

%i[ignore treat_as_incorrect treat_as_correct].each do |strategy|
  puts "\nMissing Strategy: #{strategy}"
  puts "-" * 30

  Benchmark.ips do |x|
    x.config(time: 3, warmup: 1)

    x.report("Rasch") do
      model = IrtRuby::RaschModel.new(data_with_missing, max_iter: 50, missing_strategy: strategy)
      model.fit
    end
  end
end

puts "\n#{"=" * 60}"
puts "Benchmark Complete!"
puts "=" * 60
