# frozen_string_literal: true

module IrtRuby
  # Validates optimization hyperparameters shared by IRT model implementations.
  module ModelOptionsValidator
    module_function

    def validate!(max_iter:, tolerance:, param_tolerance:, learning_rate:, decay_factor:)
      validate_positive_integer!(:max_iter, max_iter)
      validate_positive_finite_numeric!(:tolerance, tolerance)
      validate_positive_finite_numeric!(:param_tolerance, param_tolerance)
      validate_positive_finite_numeric!(:learning_rate, learning_rate)
      validate_decay_factor!(decay_factor)
    end

    def validate_positive_integer!(name, value)
      return if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive Integer"
    end

    def validate_positive_finite_numeric!(name, value)
      return if finite_numeric?(value) && value.positive?

      raise ArgumentError, "#{name} must be a positive finite Numeric"
    end

    def validate_decay_factor!(value)
      return if finite_numeric?(value) && value.positive? && value < 1

      raise ArgumentError, "decay_factor must be a finite Numeric strictly between 0 and 1"
    end

    def finite_numeric?(value)
      value.is_a?(Numeric) && !value.is_a?(Complex) && value.finite?
    end
  end
end
