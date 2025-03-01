# frozen_string_literal: true

module IrtRuby
  # A class representing the Rasch model for Item Response Theory (ability - difficulty).
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling (skip nil)
  # - Multiple convergence checks (log-likelihood + parameter updates)
  class RaschModel
    MISSING_STRATEGIES = %i[ignore treat_as_incorrect treat_as_correct].freeze

    def initialize(data,
                   max_iter: 1000,
                   tolerance: 1e-6,
                   param_tolerance: 1e-6,
                   learning_rate: 0.01,
                   decay_factor: 0.5,
                   missing_strategy: :ignore)
      # data: A Matrix or array-of-arrays of responses (0/1 or nil for missing).
      # missing_strategy: :ignore (skip), :treat_as_incorrect, :treat_as_correct

      @data = data
      @data_array = data.to_a
      num_rows = @data_array.size
      num_cols = @data_array.first.size

      raise ArgumentError, "missing_strategy must be one of #{MISSING_STRATEGIES}" unless MISSING_STRATEGIES.include?(missing_strategy)

      @missing_strategy = missing_strategy

      # Initialize parameters near zero
      @abilities    = Array.new(num_rows)  { rand(-0.25..0.25) }
      @difficulties = Array.new(num_cols)  { rand(-0.25..0.25) }

      @max_iter        = max_iter
      @tolerance       = tolerance
      @param_tolerance = param_tolerance
      @learning_rate   = learning_rate
      @decay_factor    = decay_factor
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    def resolve_missing(resp)
      return [resp, false] unless resp.nil?

      case @missing_strategy
      when :ignore
        [nil, true]
      when :treat_as_incorrect
        [0, false]
      when :treat_as_correct
        [1, false]
      end
    end

    def log_likelihood
      total_ll = 0.0
      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          value, skip = resolve_missing(resp)
          next if skip

          prob = sigmoid(@abilities[i] - @difficulties[j])
          total_ll += if value == 1
                        Math.log(prob + 1e-15)
                      else
                        Math.log((1 - prob) + 1e-15)
                      end
        end
      end
      total_ll
    end

    def compute_gradient
      grad_abilities    = Array.new(@abilities.size, 0.0)
      grad_difficulties = Array.new(@difficulties.size, 0.0)

      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          value, skip = resolve_missing(resp)
          next if skip

          prob = sigmoid(@abilities[i] - @difficulties[j])
          error = value - prob

          grad_abilities[i]    += error
          grad_difficulties[j] -= error
        end
      end

      [grad_abilities, grad_difficulties]
    end

    def apply_gradient_update(grad_abilities, grad_difficulties)
      old_abilities    = @abilities.dup
      old_difficulties = @difficulties.dup

      @abilities.each_index do |i|
        @abilities[i] += @learning_rate * grad_abilities[i]
      end

      @difficulties.each_index do |j|
        @difficulties[j] += @learning_rate * grad_difficulties[j]
      end

      [old_abilities, old_difficulties]
    end

    def average_param_update(old_abilities, old_difficulties)
      deltas = []
      @abilities.each_with_index do |a, i|
        deltas << (a - old_abilities[i]).abs
      end
      @difficulties.each_with_index do |d, j|
        deltas << (d - old_difficulties[j]).abs
      end
      deltas.sum / deltas.size
    end

    def fit
      prev_ll = log_likelihood

      @max_iter.times do
        grad_abilities, grad_difficulties = compute_gradient

        old_a, old_d = apply_gradient_update(grad_abilities, grad_difficulties)

        current_ll  = log_likelihood
        param_delta = average_param_update(old_a, old_d)

        if current_ll < prev_ll
          @abilities    = old_a
          @difficulties = old_d
          @learning_rate *= @decay_factor
        else
          ll_diff = (current_ll - prev_ll).abs
          break if ll_diff < @tolerance && param_delta < @param_tolerance

          prev_ll = current_ll
        end
      end

      { abilities: @abilities, difficulties: @difficulties }
    end
  end
end
