#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "irt_ruby"
require "benchmark"

# Enhanced model classes that track iterations and convergence
class TrackedRaschModel < IrtRuby::RaschModel
  attr_reader :iterations, :final_log_likelihood, :convergence_reason

  def fit
    @iterations = 0
    prev_ll = log_likelihood
    @final_log_likelihood = prev_ll
    @convergence_reason = :max_iterations

    @max_iter.times do
      @iterations += 1
      grad_abilities, grad_difficulties = compute_gradient

      old_a, old_d = apply_gradient_update(grad_abilities, grad_difficulties)

      current_ll = log_likelihood
      param_delta = average_param_update(old_a, old_d)

      if current_ll < prev_ll
        @abilities = old_a
        @difficulties = old_d
        @learning_rate *= @decay_factor
      else
        ll_diff = (current_ll - prev_ll).abs
        @final_log_likelihood = current_ll

        if ll_diff < @tolerance && param_delta < @param_tolerance
          @convergence_reason = :tolerance_reached
          break
        end

        prev_ll = current_ll
      end
    end

    { abilities: @abilities, difficulties: @difficulties }
  end
end

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
  convergence_reasons = []

  5.times do
    time = Benchmark.measure do
      model = TrackedRaschModel.new(
        data,
        max_iter: 2000,
        tolerance: config[:tolerance],
        param_tolerance: config[:param_tolerance],
        learning_rate: 0.01
      )
      model.fit
      iterations << model.iterations
      convergence_reasons << model.convergence_reason
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergence_reasons.count(:tolerance_reached) / 5.0

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
  convergence_reasons = []

  5.times do
    time = Benchmark.measure do
      model = TrackedRaschModel.new(
        data,
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: config[:rate]
      )
      model.fit
      iterations << model.iterations
      convergence_reasons << model.convergence_reason
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergence_reasons.count(:tolerance_reached) / 5.0

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
  convergence_reasons = []

  3.times do
    dataset = generate_data(
      config[:people],
      config[:items],
      difficulty_range: config[:diff_range],
      ability_range: config[:ability_range]
    )

    time = Benchmark.measure do
      model = TrackedRaschModel.new(
        dataset[:data],
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: 0.01
      )
      model.fit
      iterations << model.iterations
      convergence_reasons << model.convergence_reason
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergence_reasons.count(:tolerance_reached) / 3.0

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

  data_with_missing = if (config[:rate]).positive?
                        base_data.map do |row|
                          row.map { |resp| rand < config[:rate] ? nil : resp }
                        end
                      else
                        base_data
                      end

  times = []
  iterations = []
  convergence_reasons = []

  3.times do
    time = Benchmark.measure do
      model = TrackedRaschModel.new(
        data_with_missing,
        max_iter: 1000,
        tolerance: 1e-5,
        param_tolerance: 1e-5,
        learning_rate: 0.01,
        missing_strategy: config[:strategy]
      )
      model.fit
      iterations << model.iterations
      convergence_reasons << model.convergence_reason
    end.real
    times << time
  end

  avg_time = times.sum / times.size
  avg_iterations = iterations.sum.to_f / iterations.size
  convergence_rate = convergence_reasons.count(:tolerance_reached) / 3.0

  printf("  Time: %6.3fs  Iterations: %6.1f  Convergence Rate: %4.0f%%\n",
         avg_time, avg_iterations, convergence_rate * 100)
end

puts "\n#{"=" * 70}"
puts "Convergence Analysis Complete!"
puts "=" * 70
