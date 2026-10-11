# frozen_string_literal: true

require "irt_ruby/estimation"
require "irt_ruby/model_options_validator"
require "irt_ruby/response_data_validator"

module IrtRuby
  # A class representing the Rasch model for Item Response Theory (ability - difficulty).
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling (skip nil)
  # - Multiple convergence checks (log-likelihood + parameter updates)
  # - Exclusion of extreme response patterns, which have no finite estimates
  # - Identification by centering abilities at zero
  class RaschModel
    MISSING_STRATEGIES = %i[ignore treat_as_incorrect treat_as_correct].freeze

    def initialize(data,
                   max_iter: 1000,
                   tolerance: 1e-6,
                   param_tolerance: 1e-6,
                   gradient_tolerance: 1e-3,
                   learning_rate: 0.01,
                   decay_factor: 0.5,
                   missing_strategy: :ignore,
                   seed: nil)
      # data: A Matrix or array-of-arrays of responses (0/1 or nil for missing).
      # missing_strategy: :ignore (skip), :treat_as_incorrect, :treat_as_correct

      ModelOptionsValidator.validate!(max_iter: max_iter,
                                      tolerance: tolerance,
                                      param_tolerance: param_tolerance,
                                      gradient_tolerance: gradient_tolerance,
                                      learning_rate: learning_rate,
                                      decay_factor: decay_factor)

      data_array = ResponseDataValidator.validate!(data)
      num_rows = data_array.size
      num_cols = data_array.first.size

      raise ArgumentError, "missing_strategy must be one of #{MISSING_STRATEGIES}" unless MISSING_STRATEGIES.include?(missing_strategy)

      @missing_strategy = missing_strategy
      @random = seed.nil? ? nil : Random.new(seed)

      @responses = data_array.map { |row| row.map { |resp| resolve_missing(resp).first } }
      @active_persons, @active_items = Estimation.estimable(@responses)
      @person_counts, @item_counts = Estimation.response_counts(@responses, @active_persons, @active_items)

      # Initialize parameters near zero
      @abilities    = Array.new(num_rows)  { random_between(-0.25..0.25) }
      @difficulties = Array.new(num_cols)  { random_between(-0.25..0.25) }

      @max_iter           = max_iter
      @tolerance          = tolerance
      @param_tolerance    = param_tolerance
      @gradient_tolerance = gradient_tolerance
      @learning_rate      = learning_rate
      @decay_factor       = decay_factor
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    def random_between(range)
      @random ? @random.rand(range) : rand(range)
    end
    private :random_between

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
      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        z = @abilities[i] - @difficulties[j]
        total_ll += Estimation.log_sigmoid(value == 1 ? z : -z)
      end
      total_ll
    end

    def compute_gradient
      grad_abilities    = Array.new(@abilities.size, 0.0)
      grad_difficulties = Array.new(@difficulties.size, 0.0)

      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        error = value - sigmoid(@abilities[i] - @difficulties[j])

        grad_abilities[i]    += error
        grad_difficulties[j] -= error
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
      deltas = Estimation.changes(@abilities, old_abilities, @active_persons) +
               Estimation.changes(@difficulties, old_difficulties, @active_items)
      deltas.sum / deltas.size
    end

    # Returns estimates with nil for persons and items excluded as extreme or
    # unobserved, plus whether the convergence criteria were met.
    def fit
      converged = false
      iterations = 0

      if @active_persons.any?
        prev_ll = log_likelihood

        @max_iter.times do
          iterations += 1
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
            if ll_diff < @tolerance && param_delta < @param_tolerance
              converged = stationary?
              break
            end

            prev_ll = current_ll
            @learning_rate *= Estimation::LEARNING_RATE_GROWTH
          end
        end

        center_abilities
      end

      {
        abilities: Estimation.estimates(@abilities, @active_persons),
        difficulties: Estimation.estimates(@difficulties, @active_items),
        converged: converged,
        iterations: iterations
      }
    end

    def stationary?
      grad_abilities, grad_difficulties = compute_gradient
      Estimation.stationary?(grad_abilities, [grad_difficulties], @person_counts, @item_counts, @gradient_tolerance)
    end
    private :stationary?

    def center_abilities
      mean, = Estimation.mean_and_sd(@abilities.select.with_index { |_, i| @active_persons[i] })
      @abilities.map! { |theta| theta - mean }
      @difficulties.map! { |b| b - mean }
    end
    private :center_abilities
  end
end
