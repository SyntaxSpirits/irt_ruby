# frozen_string_literal: true

module IrtRuby
  # Validates response data accepted by IRT model constructors.
  module ResponseDataValidator
    module_function

    def validate!(data)
      raise ArgumentError, "response data must be a Matrix or array of arrays" unless valid_data_container?(data)

      data_array = data.to_a

      raise ArgumentError, "response data must have at least one row" unless data_array.is_a?(Array) && data_array.any?

      validate_rows!(data_array)
      validate_values!(data_array)

      data_array
    end

    def validate_rows!(data_array)
      first_row = data_array.first

      raise ArgumentError, "response data must be a Matrix or array of arrays" unless first_row.is_a?(Array)

      expected_columns = first_row.size
      raise ArgumentError, "response data must have at least one column" if expected_columns.zero?

      data_array.each_with_index do |row, index|
        raise ArgumentError, "response data row #{index} must be an Array" unless row.is_a?(Array)

        next if row.size == expected_columns

        raise ArgumentError, "response data must be rectangular; row #{index} has #{row.size} columns, expected #{expected_columns}"
      end
    end

    def validate_values!(data_array)
      data_array.each_with_index do |row, row_index|
        row.each_with_index do |value, column_index|
          next if valid_response?(value)

          raise ArgumentError,
                "response data contains invalid value #{value.inspect} at row #{row_index + 1}, column #{column_index + 1}; allowed values are 0, 1, and nil"
        end
      end
    end

    def valid_response?(value)
      value.nil? || value.eql?(0) || value.eql?(1)
    end

    def valid_data_container?(data)
      data.is_a?(Array) || (defined?(::Matrix) && data.is_a?(::Matrix))
    end
  end
end
