# frozen_string_literal: true

module IrtRuby
  # A class representing the Three-Parameter model (3PL) for Item Response Theory.
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling
  # - Parameter clamping for discrimination, guessing
  # - Multiple convergence checks
  # - Separate gradient calculation & updates
  class ThreeParameterModel
    MISSING_STRATEGIES = %i[ignore treat_as_incorrect treat_as_correct].freeze

    def initialize(data,
                   max_iter: 1000,
                   tolerance: 1e-6,
                   param_tolerance: 1e-6,
                   learning_rate: 0.01,
                   decay_factor: 0.5,
                   missing_strategy: :ignore)
      @data = data
      @data_array = data.to_a
      num_rows = @data_array.size
      num_cols = @data_array.first.size

      raise ArgumentError, "missing_strategy must be one of #{MISSING_STRATEGIES}" unless MISSING_STRATEGIES.include?(missing_strategy)

      @missing_strategy = missing_strategy

      # Initialize parameters
      @abilities       = Array.new(num_rows)  { rand(-0.25..0.25) }
      @difficulties    = Array.new(num_cols)  { rand(-0.25..0.25) }
      @discriminations = Array.new(num_cols)  { rand(0.5..1.5) }
      @guessings       = Array.new(num_cols)  { rand(0.0..0.3) }

      @max_iter        = max_iter
      @tolerance       = tolerance
      @param_tolerance = param_tolerance
      @learning_rate   = learning_rate
      @decay_factor    = decay_factor
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

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
      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          value, skip = resolve_missing(resp)
          next if skip

          prob = probability(@abilities[i],
                             @discriminations[j],
                             @difficulties[j],
                             @guessings[j])

          ll += if value == 1
                  Math.log(prob + 1e-15)
                else
                  Math.log((1 - prob) + 1e-15)
                end
        end
      end
      ll
    end

    def compute_gradient
      grad_abilities       = Array.new(@abilities.size, 0.0)
      grad_difficulties    = Array.new(@difficulties.size, 0.0)
      grad_discriminations = Array.new(@discriminations.size, 0.0)
      grad_guessings       = Array.new(@guessings.size, 0.0)

      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          value, skip = resolve_missing(resp)
          next if skip

          theta = @abilities[i]
          a     = @discriminations[j]
          b     = @difficulties[j]
          c     = @guessings[j]

          prob  = probability(theta, a, b, c)
          error = value - prob

          grad_abilities[i]       += error * a * (1 - c)
          grad_difficulties[j]    -= error * a * (1 - c)
          grad_discriminations[j] += error * (theta - b) * (1 - c)

          grad_guessings[j]       += error * 1.0
        end
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
        @discriminations[j] += @learning_rate * gdisc[j]
        @discriminations[j] = 0.01 if @discriminations[j] < 0.01
        @discriminations[j] = 5.0  if @discriminations[j] > 5.0
      end

      @guessings.each_index do |j|
        @guessings[j] += @learning_rate * gc[j]
        @guessings[j] = 0.0  if @guessings[j] < 0.0
        @guessings[j] = 0.35 if @guessings[j] > 0.35
      end

      [old_a, old_d, old_disc, old_c]
    end

    def average_param_update(old_a, old_d, old_disc, old_c)
      deltas = []
      @abilities.each_with_index       { |x, i| deltas << (x - old_a[i]).abs }
      @difficulties.each_with_index    { |x, j| deltas << (x - old_d[j]).abs }
      @discriminations.each_with_index { |x, j| deltas << (x - old_disc[j]).abs }
      @guessings.each_with_index       { |x, j| deltas << (x - old_c[j]).abs }
      deltas.sum / deltas.size
    end

    def fit
      prev_ll = log_likelihood

      @max_iter.times do
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
          break if ll_diff < @tolerance && param_delta < @param_tolerance

          prev_ll = curr_ll
        end
      end

      {
        abilities: @abilities,
        difficulties: @difficulties,
        discriminations: @discriminations,
        guessings: @guessings
      }
    end
  end
end
