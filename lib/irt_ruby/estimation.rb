# frozen_string_literal: true

module IrtRuby
  # Numerical helpers shared by IRT model implementations.
  # @api private
  module Estimation
    # Learning-rate multiplier after an accepted step, so the rate can recover from earlier decays.
    LEARNING_RATE_GROWTH = 1.1

    module_function

    def log_sigmoid(x)
      x >= 0 ? -Math.log(1.0 + Math.exp(-x)) : x - Math.log(1.0 + Math.exp(x))
    end

    def each_response(responses, persons, items)
      responses.each_with_index do |row, i|
        next unless persons[i]

        row.each_with_index do |value, j|
          next if value.nil? || !items[j]

          yield i, j, value
        end
      end
    end

    def response_counts(responses, persons, items)
      person_counts = Array.new(responses.size, 0)
      item_counts = Array.new(responses.first.size, 0)
      each_response(responses, persons, items) do |i, j, _value|
        person_counts[i] += 1
        item_counts[j] += 1
      end
      [person_counts, item_counts]
    end

    # True when every gradient component, averaged over the responses it sums, is below tolerance.
    def stationary?(person_gradient, item_gradients, person_counts, item_counts, tolerance)
      small_residuals?(person_gradient, person_counts, tolerance) &&
        item_gradients.all? { |gradient| small_residuals?(gradient, item_counts, tolerance) }
    end

    def small_residuals?(gradient, counts, tolerance)
      gradient.each_index.all? { |k| counts[k].zero? || (gradient[k] / counts[k]).abs < tolerance }
    end

    # Drops gradient components that push a parameter further past the bound it sits on.
    def project(gradient, values, min, max)
      gradient.each_index.map do |k|
        blocked = (values[k] <= min && gradient[k].negative?) || (values[k] >= max && gradient[k].positive?)
        blocked ? 0.0 : gradient[k]
      end
    end

    # Location and scale of the estimable abilities, used to report parameters on a fixed scale.
    def scale(abilities, active)
      values = abilities.select.with_index { |_, i| active[i] }
      return [0.0, 1.0] if values.empty?

      mean, sd = mean_and_sd(values)
      [mean, sd.zero? ? 1.0 : sd]
    end

    def mean_and_sd(values)
      mean = values.sum / values.size
      [mean, Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size)]
    end

    def changes(current, previous, active)
      current.each_index.select { |k| active[k] }.map { |k| (current[k] - previous[k]).abs }
    end

    def estimates(values, active)
      values.each_index.map { |k| active[k] ? values[k] : nil }
    end
  end
end
