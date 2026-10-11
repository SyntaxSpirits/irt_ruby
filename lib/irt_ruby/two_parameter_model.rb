# frozen_string_literal: true

require "irt_ruby/estimation"
require "irt_ruby/model_options_validator"
require "irt_ruby/response_data_validator"
require "irt_ruby/response_graph"

module IrtRuby
  # A class representing the Two-Parameter model (2PL) for IRT.
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling
  # - Parameter clamping for discrimination
  # - Multiple convergence checks
  # - Separate gradient calculation & parameter update
  # - Exclusion of extreme response patterns, which have no finite estimates
  # - Identification by reporting abilities standardized to mean 0 and SD 1
  class TwoParameterModel
    MISSING_STRATEGIES = %i[ignore treat_as_incorrect treat_as_correct].freeze
    DISCRIMINATION_BOUNDS = [0.01, 5.0].freeze

    def initialize(data, max_iter: 1000, tolerance: 1e-6, param_tolerance: 1e-6,
                   gradient_tolerance: 1e-3,
                   learning_rate: 0.01, decay_factor: 0.5,
                   missing_strategy: :ignore, seed: nil)
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
      @active_persons, @active_items = ResponseGraph.estimable(@responses)
      @person_counts, @item_counts = Estimation.response_counts(@responses, @active_persons, @active_items)

      # Initialize parameters
      # Typically: ability ~ 0, difficulty ~ 0, discrimination ~ 1
      @abilities       = Array.new(num_rows)  { random_between(-0.25..0.25) }
      @difficulties    = Array.new(num_cols)  { random_between(-0.25..0.25) }
      @discriminations = Array.new(num_cols)  { random_between(0.5..1.5) }

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
      ll = 0.0
      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        z = @discriminations[j] * (@abilities[i] - @difficulties[j])
        ll += Estimation.log_sigmoid(value == 1 ? z : -z)
      end
      ll
    end

    def compute_gradient
      grad_abilities       = Array.new(@abilities.size, 0.0)
      grad_difficulties    = Array.new(@difficulties.size, 0.0)
      grad_discriminations = Array.new(@discriminations.size, 0.0)

      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        prob  = sigmoid(@discriminations[j] * (@abilities[i] - @difficulties[j]))
        error = value - prob

        grad_abilities[i]       += error * @discriminations[j]
        grad_difficulties[j]    -= error * @discriminations[j]
        grad_discriminations[j] += error * (@abilities[i] - @difficulties[j])
      end

      [grad_abilities, grad_difficulties, grad_discriminations]
    end

    def apply_gradient_update(ga, gd, gdisc)
      old_a    = @abilities.dup
      old_d    = @difficulties.dup
      old_disc = @discriminations.dup

      @abilities.each_index do |i|
        @abilities[i] += @learning_rate * ga[i]
      end

      @difficulties.each_index do |j|
        @difficulties[j] += @learning_rate * gd[j]
      end

      @discriminations.each_index do |j|
        @discriminations[j] = (@discriminations[j] + (@learning_rate * gdisc[j])).clamp(*DISCRIMINATION_BOUNDS)
      end

      [old_a, old_d, old_disc]
    end

    def average_param_update(old_a, old_d, old_disc)
      deltas = Estimation.changes(@abilities, old_a, @active_persons) +
               Estimation.changes(@difficulties, old_d, @active_items) +
               Estimation.changes(@discriminations, old_disc, @active_items)
      deltas.sum / deltas.size
    end

    # Returns estimates on the identified scale, with nil for persons and items that
    # have no finite estimate on it, plus whether the convergence criteria were met.
    def fit
      converged = false
      iterations = 0

      if @active_persons.any?
        prev_ll = log_likelihood

        @max_iter.times do
          iterations += 1
          ga, gd, gdisc = compute_gradient
          old_a, old_d, old_disc = apply_gradient_update(ga, gd, gdisc)

          curr_ll     = log_likelihood
          param_delta = average_param_update(old_a, old_d, old_disc)

          if curr_ll < prev_ll
            @abilities       = old_a
            @difficulties    = old_d
            @discriminations = old_disc
            @learning_rate  *= @decay_factor
          else
            ll_diff = (curr_ll - prev_ll).abs
            if ll_diff < @tolerance && param_delta < @param_tolerance
              converged = stationary?
              break
            end

            prev_ll = curr_ll
            @learning_rate *= Estimation::LEARNING_RATE_GROWTH
          end
        end

      end

      mean, sd = Estimation.scale(@abilities, @active_persons)
      {
        abilities: Estimation.estimates(@abilities.map { |theta| (theta - mean) / sd }, @active_persons),
        difficulties: Estimation.estimates(@difficulties.map { |b| (b - mean) / sd }, @active_items),
        discriminations: Estimation.estimates(@discriminations.map { |a| a * sd }, @active_items),
        converged: converged,
        iterations: iterations
      }
    end

    # Gradients are compared on the reported scale (theta' = (theta - m) / sd,
    # b' = (b - m) / sd, a' = a * sd), where they scale by sd, sd and 1 / sd.
    def stationary?
      ga, gd, gdisc = compute_gradient
      gdisc = Estimation.project(gdisc, @discriminations, *DISCRIMINATION_BOUNDS)
      _, sd = Estimation.scale(@abilities, @active_persons)
      Estimation.stationary?(ga.map { |g| g * sd },
                             [gd.map { |g| g * sd }, gdisc.map { |g| g / sd }],
                             @person_counts, @item_counts, @gradient_tolerance)
    end
    private :stationary?
  end
end
