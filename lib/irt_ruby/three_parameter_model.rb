# frozen_string_literal: true

require "matrix"

module IrtRuby
  # A class representing the Three-Parameter model for Item Response Theory.
  class ThreeParameterModel
    def initialize(data, max_iter: 1000, tolerance: 1e-6, learning_rate: 0.01)
      @data = data
      @abilities = Array.new(data.row_count) { rand }
      @difficulties = Array.new(data.column_count) { rand }
      @discriminations = Array.new(data.column_count) { rand }
      @guessings = Array.new(data.column_count) { rand * 0.3 }
      @max_iter = max_iter
      @tolerance = tolerance
      @learning_rate = learning_rate
    end

    # Sigmoid function to calculate probability
    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    # Probability function for the 3PL model
    def probability(theta, a, b, c)
      c + (1 - c) * sigmoid(a * (theta - b))
    end

    # Calculate the log-likelihood of the data given the current parameters
    def likelihood
      likelihood = 0
      @data.row_vectors.each_with_index do |row, i|
        row.to_a.each_with_index do |response, j|
          prob = probability(@abilities[i], @discriminations[j], @difficulties[j], @guessings[j])
          likelihood += response == 1 ? Math.log(prob) : Math.log(1 - prob)
        end
      end
      likelihood
    end

    # Update parameters using gradient ascent
    def update_parameters
      last_likelihood = likelihood
      @max_iter.times do |_iter|
        @data.row_vectors.each_with_index do |row, i|
          row.to_a.each_with_index do |response, j|
            prob = probability(@abilities[i], @discriminations[j], @difficulties[j], @guessings[j])
            error = response - prob
            @abilities[i] += @learning_rate * error * @discriminations[j]
            @difficulties[j] -= @learning_rate * error * @discriminations[j]
            @discriminations[j] += @learning_rate * error * (@abilities[i] - @difficulties[j])
            @guessings[j] += @learning_rate * error * (1 - prob)
            @guessings[j] = [[@guessings[j], 0].max, 1].min # Keep guessings within [0, 1]
          end
        end
        current_likelihood = likelihood
        break if (last_likelihood - current_likelihood).abs < @tolerance

        last_likelihood = current_likelihood
      end
    end

    # Fit the model to the data
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
