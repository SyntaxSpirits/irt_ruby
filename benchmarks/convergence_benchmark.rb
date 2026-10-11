#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "irt_ruby"
require "benchmark"

def generate_data(num_people, num_items, difficulty_range: (-2..2), ability_range: (-2..2))
  # Generate realistic IRT data based on known parameters
  true_abilities = Array.new(num_people) { rand(ability_range) }
  true_difficulties = Array.new(num_items) { rand(difficulty_range) }

  data = Array.new(num_people) do |person|
    Array.new(num_items) do |item|
      prob = 1.0 / (1.0 + Math.exp(-(true_abilities[person] - true_difficulties[item])))
      rand < prob ? 1 : 0
    end
  end

  { data: data, true_abilities: true_abilities, true_difficulties: true_difficulties }
end

puts "=" * 70
puts "IRT Ruby Convergence Analysis"
puts "=" * 70
puts

# Test convergence with different tolerance settings
tolerance_configs = [
  { tolerance: 1e-3, param_tolerance: 1e-3, label: "Loose (1e-3)" },
  { tolerance: 1e-4, param_tolerance: 1e-4, label: "Medium (1e-4)" },
  { tolerance: 1e-5, param_tolerance: 1e-5, label: "Tight (1e-5)" },
  { tolerance: 1e-6, param_tolerance: 1e-6, label: "Very Tight (1e-6)" }
]

dataset = generate_data(100, 50)
data = dataset[:data]

puts "Convergence Analysis - Impact of Tolerance Settings"
puts "-" * 50

tolerance_configs.each do |config|
  puts "\nTolerance: #{config[:label]}"

  times = []
  iterations = []
  convergences = []

  5.times do
    time = Benchmark.measure do
      model = IrtRuby::RaschModel.new(
        data,
        max_iter: 2000,
        tolerance: config[:tolerance],
        param_tolerance: config[:param_tolerance],
        learning_rate: 0.01
      )
      result = model.fit
      iterations << result[:iterations]
      convergences << result[:converged]
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergences.count(true) / 5.0

  printf("  Time: %6.3fs  Iterations: %6.1f  Convergence Rate: %4.0f%%\n",
         avg_time, avg_iterations, convergence_rate * 100)
end

# Test convergence with different learning rates
puts "\n#{"=" * 70}"
puts "Learning Rate Impact Analysis"
puts "-" * 50

learning_rate_configs = [
  { rate: 0.001, label: "Very Slow (0.001)" },
  { rate: 0.01, label: "Slow (0.01)" },
  { rate: 0.05, label: "Medium (0.05)" },
  { rate: 0.1, label: "Fast (0.1)" },
  { rate: 0.2, label: "Very Fast (0.2)" }
]

learning_rate_configs.each do |config|
  puts "\nLearning Rate: #{config[:label]}"

  times = []
  iterations = []
  convergences = []

  5.times do
    time = Benchmark.measure do
      model = IrtRuby::RaschModel.new(
        data,
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: config[:rate]
      )
      result = model.fit
      iterations << result[:iterations]
      convergences << result[:converged]
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergences.count(true) / 5.0

  printf("  Time: %6.3fs  Iterations: %6.1f  Convergence Rate: %4.0f%%\n",
         avg_time, avg_iterations, convergence_rate * 100)
end

# Test convergence with different dataset characteristics
puts "\n#{"=" * 70}"
puts "Dataset Characteristics Impact"
puts "-" * 50

dataset_configs = [
  { people: 50, items: 25, diff_range: (-1..1), ability_range: (-1..1), label: "Easy (narrow ranges)" },
  { people: 100, items: 50, diff_range: (-2..2), ability_range: (-2..2), label: "Medium (standard ranges)" },
  { people: 100, items: 50, diff_range: (-3..3), ability_range: (-3..3), label: "Hard (wide ranges)" },
  { people: 200, items: 100, diff_range: (-2..2), ability_range: (-2..2), label: "Large (more data)" }
]

dataset_configs.each do |config|
  puts "\nDataset: #{config[:label]}"

  times = []
  iterations = []
  convergences = []

  3.times do
    dataset = generate_data(
      config[:people],
      config[:items],
      difficulty_range: config[:diff_range],
      ability_range: config[:ability_range]
    )

    time = Benchmark.measure do
      model = IrtRuby::RaschModel.new(
        dataset[:data],
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: 0.01
      )
      result = model.fit
      iterations << result[:iterations]
      convergences << result[:converged]
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergences.count(true) / 3.0

  printf("  Time: %6.3fs  Iterations: %6.1f  Convergence Rate: %4.0f%%\n",
         avg_time, avg_iterations, convergence_rate * 100)
end

# Test different missing data patterns
puts "\n#{"=" * 70}"
puts "Missing Data Pattern Impact"
puts "-" * 50

missing_configs = [
  { rate: 0.0, strategy: :ignore, label: "No Missing Data" },
  { rate: 0.1, strategy: :ignore, label: "10% Missing (ignore)" },
  { rate: 0.2, strategy: :ignore, label: "20% Missing (ignore)" },
  { rate: 0.2, strategy: :treat_as_incorrect, label: "20% Missing (incorrect)" },
  { rate: 0.2, strategy: :treat_as_correct, label: "20% Missing (correct)" }
]

missing_configs.each do |config|
  puts "\nMissing Data: #{config[:label]}"

  # Generate data with missing values
  base_data = generate_data(100, 50)[:data]

  data_with_missing = if config[:rate].positive?
                        base_data.map do |row|
                          row.map { |resp| rand < config[:rate] ? nil : resp }
                        end
                      else
                        base_data
                      end

  times = []
  iterations = []
  convergences = []

  3.times do
    time = Benchmark.measure do
      model = IrtRuby::RaschModel.new(
        data_with_missing,
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: 0.01,
        missing_strategy: config[:strategy]
      )
      result = model.fit
      iterations << result[:iterations]
      convergences << result[:converged]
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergences.count(true) / 3.0

  printf("  Time: %6.3fs  Iterations: %6.1f  Convergence Rate: %4.0f%%\n",
         avg_time, avg_iterations, convergence_rate * 100)
end

puts "\n#{"=" * 70}"
puts "Convergence Analysis Complete!"
puts "=" * 70
