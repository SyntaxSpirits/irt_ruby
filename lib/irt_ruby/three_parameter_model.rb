# frozen_string_literal: true

require "irt_ruby/estimation"
require "irt_ruby/model_options_validator"
require "irt_ruby/response_data_validator"

module IrtRuby
  # A class representing the Three-Parameter model (3PL) for Item Response Theory.
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling
  # - Parameter clamping for discrimination, guessing
  # - Multiple convergence checks
  # - Separate gradient calculation & updates
  # - Exclusion of extreme response patterns, which have no finite estimates
  # - Identification by standardizing abilities to mean 0 and SD 1
  class ThreeParameterModel
    MISSING_STRATEGIES = %i[ignore treat_as_incorrect treat_as_correct].freeze
    DISCRIMINATION_BOUNDS = [0.01, 5.0].freeze
    GUESSING_BOUNDS = [0.0, 0.35].freeze

    def initialize(data,
                   max_iter: 1000,
                   tolerance: 1e-6,
                   param_tolerance: 1e-6,
                   gradient_tolerance: 1e-3,
                   learning_rate: 0.01,
                   decay_factor: 0.5,
                   missing_strategy: :ignore,
                   seed: nil)
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

      # Initialize parameters
      @abilities       = Array.new(num_rows)  { random_between(-0.25..0.25) }
      @difficulties    = Array.new(num_cols)  { random_between(-0.25..0.25) }
      @discriminations = Array.new(num_cols)  { random_between(0.5..1.5) }
      @guessings       = Array.new(num_cols)  { random_between(0.0..0.3) }

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

    # Probability for the 3PL model: c + (1-c)*sigmoid(a*(θ - b))
    def probability(theta, a, b, c)
      c + ((1.0 - c) * sigmoid(a * (theta - b)))
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
      ll = 0.0
      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        z = @discriminations[j] * (@abilities[i] - @difficulties[j])
        c = @guessings[j]

        ll += if value == 1
                c.zero? ? Estimation.log_sigmoid(z) : Math.log(c + ((1.0 - c) * sigmoid(z)))
              else
                Math.log(1.0 - c) + Estimation.log_sigmoid(-z)
              end
      end
      ll
    end

    def compute_gradient
      grad_abilities       = Array.new(@abilities.size, 0.0)
      grad_difficulties    = Array.new(@difficulties.size, 0.0)
      grad_discriminations = Array.new(@discriminations.size, 0.0)
      grad_guessings       = Array.new(@guessings.size, 0.0)

      Estimation.each_response(@responses, @active_persons, @active_items) do |i, j, value|
        theta = @abilities[i]
        a     = @discriminations[j]
        b     = @difficulties[j]
        c     = @guessings[j]

        # With P = c + (1 - c) * s and s = sigmoid(a * (theta - b)):
        # dLL/dz = (u - P) * s / P and dLL/dc = (u - P) / ((1 - c) * P).
        s     = sigmoid(a * (theta - b))
        prob  = c + ((1.0 - c) * s)
        error = value - prob
        dz    = prob.zero? ? error : error * s / prob

        grad_abilities[i]       += dz * a
        grad_difficulties[j]    -= dz * a
        grad_discriminations[j] += dz * (theta - b)
        grad_guessings[j]       += prob.zero? ? 0.0 : error / ((1.0 - c) * prob)
      end

      [grad_abilities, grad_difficulties, grad_discriminations, grad_guessings]
    end

    def apply_gradient_update(ga, gd, gdisc, gc)
      old_a    = @abilities.dup
      old_d    = @difficulties.dup
      old_disc = @discriminations.dup
      old_c    = @guessings.dup

      @abilities.each_index do |i|
        @abilities[i] += @learning_rate * ga[i]
      end

      @difficulties.each_index do |j|
        @difficulties[j] += @learning_rate * gd[j]
      end

      @discriminations.each_index do |j|
        @discriminations[j] = (@discriminations[j] + (@learning_rate * gdisc[j])).clamp(*DISCRIMINATION_BOUNDS)
      end

      @guessings.each_index do |j|
        @guessings[j] = (@guessings[j] + (@learning_rate * gc[j])).clamp(*GUESSING_BOUNDS)
      end

      [old_a, old_d, old_disc, old_c]
    end

    def average_param_update(old_a, old_d, old_disc, old_c)
      deltas = Estimation.changes(@abilities, old_a, @active_persons) +
               Estimation.changes(@difficulties, old_d, @active_items) +
               Estimation.changes(@discriminations, old_disc, @active_items) +
               Estimation.changes(@guessings, old_c, @active_items)
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
          ga, gd, gdisc, gc = compute_gradient
          old_a, old_d, old_disc, old_c = apply_gradient_update(ga, gd, gdisc, gc)

          curr_ll     = log_likelihood
          param_delta = average_param_update(old_a, old_d, old_disc, old_c)

          if curr_ll < prev_ll
            @abilities       = old_a
            @difficulties    = old_d
            @discriminations = old_disc
            @guessings       = old_c
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

        standardize_abilities
      end

      {
        abilities: Estimation.estimates(@abilities, @active_persons),
        difficulties: Estimation.estimates(@difficulties, @active_items),
        discriminations: Estimation.estimates(@discriminations, @active_items),
        guessings: Estimation.estimates(@guessings, @active_items),
        converged: converged,
        iterations: iterations
      }
    end

    def stationary?
      ga, gd, gdisc, gc = compute_gradient
      gdisc = Estimation.project(gdisc, @discriminations, *DISCRIMINATION_BOUNDS)
      gc = Estimation.project(gc, @guessings, *GUESSING_BOUNDS)
      Estimation.stationary?(ga, [gd, gdisc, gc], @person_counts, @item_counts, @gradient_tolerance)
    end
    private :stationary?

    # Rescales the latent trait without changing the likelihood: theta' = (theta - m) / s,
    # b' = (b - m) / s, a' = a * s.
    def standardize_abilities
      mean, sd = Estimation.mean_and_sd(@abilities.select.with_index { |_, i| @active_persons[i] })
      sd = 1.0 if sd.zero?
      @abilities.map! { |theta| (theta - mean) / sd }
      @difficulties.map! { |b| (b - mean) / sd }
      @discriminations.map! { |a| a * sd }
    end
    private :standardize_abilities
  end
end
