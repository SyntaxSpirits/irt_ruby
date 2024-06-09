# frozen_string_literal: true

require "matrix"

module IrtRuby
  # A class representing the Rasch model for Item Response Theory.
  class RaschModel
    def initialize(data)
      @data = data
      @abilities = Array.new(data.row_count) { rand }
      @difficulties = Array.new(data.column_count) { rand }
      @max_iter = 1000
      @tolerance = 1e-6
    end

    def sigmoid(x)
      1.0 / (1.0 + Math.exp(-x))
    end

    def likelihood
      likelihood = 0
      @data.row_vectors.each_with_index do |row, i|
        row.to_a.each_with_index do |response, j|
          prob = sigmoid(@abilities[i] - @difficulties[j])
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
            prob = sigmoid(@abilities[i] - @difficulties[j])
            error = response - prob
            @abilities[i] += 0.01 * error
            @difficulties[j] -= 0.01 * error
          end
        end
        current_likelihood = likelihood
        break if (last_likelihood - current_likelihood).abs < @tolerance

        last_likelihood = current_likelihood
      end
    end

    def fit
      update_parameters
      { abilities: @abilities, difficulties: @difficulties }
    end
  end
end