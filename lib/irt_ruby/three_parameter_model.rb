# frozen_string_literal: true

require "matrix"

module IrtRuby
  # A class representing the Three-Parameter model for Item Response Theory.
  class ThreeParameterModel
    def initialize(data, max_iter: 1000, tolerance: 1e-6)
      @data = data
      @abilities = Array.new(data.row_count) { rand }
      @difficulties = Array.new(data.column_count) { rand }
      @discriminations = Array.new(data.column_count) { rand }
      @guessings = Array.new(data.column_count) { rand * 0.3 }
      @max_iter = max_iter
      @tolerance = tolerance
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    def probability(theta, a, b, c)
      c + (1 - c) * sigmoid(a * (theta - b))
    end

    def likelihood
      likelihood = 0
      @data.row_vectors.each_with_index do |row, i|
        row.to_a.each_with_index do |response, j|
          prob = probability(@abilities[i], @discriminations[j], @difficulties[j], @guessings[j])
          if response == 1
            likelihood += Math.log(prob)
          elsif response.zero?
            likelihood += Math.log(1 - prob)
          end
        end
      end
      likelihood
    end

    def update_parameters
      last_likelihood = likelihood
      @max_iter.times do |_iter|
        @data.row_vectors.each_with_index do |row, i|
          row.to_a.each_with_index do |response, j|
            prob = probability(@abilities[i], @discriminations[j], @difficulties[j], @guessings[j])
            error = response - prob
            @abilities[i] += 0.01 * error * @discriminations[j]
            @difficulties[j] -= 0.01 * error * @discriminations[j]
            @discriminations[j] += 0.01 * error * (@abilities[i] - @difficulties[j])
            @guessings[j] += 0.01 * error * (1 - prob)
          end
        end
        current_likelihood = likelihood
        break if (last_likelihood - current_likelihood).abs < @tolerance

        last_likelihood = current_likelihood
      end
    end

    def fit
      update_parameters
      {
        abilities: @abilities,
        difficulties: @difficulties,
        discriminations: @discriminations,
        guessings: @guessings
      }
    end
  end
end
