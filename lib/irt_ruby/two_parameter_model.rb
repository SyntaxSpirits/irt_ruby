# frozen_string_literal: true

require "matrix"

module IrtRuby
  # A class representing the Two-Parameter model (2PL) for IRT.
  # Incorporates:
  # - Adaptive learning rate
  # - Missing data handling
  # - Parameter clamping for discrimination
  # - Multiple convergence checks
  # - Separate gradient calculation & parameter update
  class TwoParameterModel
    def initialize(data, max_iter: 1000, tolerance: 1e-6, param_tolerance: 1e-6,
                   learning_rate: 0.01, decay_factor: 0.5)
      @data = data
      @data_array = data.to_a
      num_rows = @data_array.size
      num_cols = @data_array.first.size

      # Initialize parameters
      # Typically: ability ~ 0, difficulty ~ 0, discrimination ~ 1
      @abilities       = Array.new(num_rows)  { rand(-0.25..0.25) }
      @difficulties    = Array.new(num_cols)  { rand(-0.25..0.25) }
      @discriminations = Array.new(num_cols)  { rand(0.5..1.5) } # Start around 1.0

      @max_iter         = max_iter
      @tolerance        = tolerance
      @param_tolerance  = param_tolerance
      @learning_rate    = learning_rate
      @decay_factor     = decay_factor
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    def log_likelihood
      ll = 0.0
      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          next if resp.nil?

          prob = sigmoid(@discriminations[j] * (@abilities[i] - @difficulties[j]))
          ll += if resp == 1
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

      @data_array.each_with_index do |row, i|
        row.each_with_index do |resp, j|
          next if resp.nil?

          prob = sigmoid(@discriminations[j] * (@abilities[i] - @difficulties[j]))
          error = resp - prob

          grad_abilities[i]       += error * @discriminations[j]
          grad_difficulties[j]    -= error * @discriminations[j]
          grad_discriminations[j] += error * (@abilities[i] - @difficulties[j])
        end
      end

      [grad_abilities, grad_difficulties, grad_discriminations]
    end

    def apply_gradient_update(ga, gd, gdisc)
      old_abilities       = @abilities.dup
      old_difficulties    = @difficulties.dup
      old_discriminations = @discriminations.dup

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

      [old_abilities, old_difficulties, old_discriminations]
    end

    def average_param_update(old_a, old_d, old_disc)
      deltas = []
      @abilities.each_with_index do |x, i|
        deltas << (x - old_a[i]).abs
      end
      @difficulties.each_with_index do |x, j|
        deltas << (x - old_d[j]).abs
      end
      @discriminations.each_with_index do |x, j|
        deltas << (x - old_disc[j]).abs
      end
      deltas.sum / deltas.size
    end

    def fit
      prev_ll = log_likelihood

      @max_iter.times do
        ga, gd, gdisc = compute_gradient
        old_a, old_d, old_disc = apply_gradient_update(ga, gd, gdisc)

        curr_ll = log_likelihood
        param_delta = average_param_update(old_a, old_d, old_disc)

        if curr_ll < prev_ll
          @abilities       = old_a
          @difficulties    = old_d
          @discriminations = old_disc
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
        discriminations: @discriminations
      }
    end
  end
end
