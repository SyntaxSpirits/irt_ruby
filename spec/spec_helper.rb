# frozen_string_literal: true

require "irt_ruby"

RSpec.shared_examples "response data validation" do
  it "rejects empty data" do
    expect { described_class.new([]) }.to raise_error(ArgumentError, /at least one row/)
  end

  it "rejects empty rows" do
    expect { described_class.new([[]]) }.to raise_error(ArgumentError, /at least one column/)
  end

  it "rejects ragged rows" do
    expect { described_class.new([[1, 0], [1]]) }.to raise_error(ArgumentError, /rectangular; row 2/)
  end

  it "rejects invalid response values" do
    expect { described_class.new([[1, 2], [0, nil]]) }.to raise_error(ArgumentError, /invalid value 2/)
  end

  it "rejects float response values that compare equal to allowed integers" do
    expect { described_class.new([[0.0]]) }.to raise_error(ArgumentError, /invalid value 0\.0/)
    expect { described_class.new([[1.0]]) }.to raise_error(ArgumentError, /invalid value 1\.0/)
  end

  it "rejects string response values" do
    expect { described_class.new([["1"]]) }.to raise_error(ArgumentError, /invalid value "1"/)
  end

  it "rejects false response values" do
    expect { described_class.new([[false]]) }.to raise_error(ArgumentError, /invalid value false/)
  end

  it "rejects true response values" do
    expect { described_class.new([[true]]) }.to raise_error(ArgumentError, /invalid value true/)
  end

  it "rejects hash input even when it can be converted to an array" do
    expect { described_class.new({ [0] => 1 }) }.to raise_error(ArgumentError, /Matrix or array of arrays/)
  end
end

RSpec.shared_examples "model optimization option validation" do
  let(:valid_data) { [[1, 0], [0, 1]] }

  {
    max_iter: [0, -1, 1.5, "100", nil],
    tolerance: [0, -1e-6, Float::INFINITY, -Float::INFINITY, Float::NAN, Complex(1, 0), "1e-6", nil],
    param_tolerance: [0, -1e-6, Float::INFINITY, -Float::INFINITY, Float::NAN, Complex(1, 0), "1e-6", nil],
    learning_rate: [0, -0.01, Float::INFINITY, -Float::INFINITY, Float::NAN, Complex(0.01, 0), "0.01", nil],
    decay_factor: [0, 1, -0.1, 1.1, Float::INFINITY, -Float::INFINITY, Float::NAN, Complex(0.5, 0), "0.5", nil]
  }.each do |option, invalid_values|
    invalid_values.each do |value|
      it "rejects #{option}=#{value.inspect}" do
        expect { described_class.new(valid_data, option => value) }.to raise_error(ArgumentError, /\A#{option} /)
      end
    end
  end
end

RSpec.shared_examples "seeded model initialization" do |parameter_names|
  let(:seeded_fit_options) { { max_iter: 50, learning_rate: 0.05 } }

  def seeded_parameter_snapshot(model, parameter_names)
    parameter_names.to_h do |parameter_name|
      [parameter_name, model.instance_variable_get("@#{parameter_name}").dup]
    end
  end

  it "produces identical initial and fitted parameters with the same seed" do
    model1 = described_class.new(data_array, **seeded_fit_options, seed: 12_345)
    model2 = described_class.new(data_array, **seeded_fit_options, seed: 12_345)

    expect(seeded_parameter_snapshot(model1, parameter_names)).to eq(
      seeded_parameter_snapshot(model2, parameter_names)
    )
    expect(model1.fit).to eq(model2.fit)
  end

  it "produces different initial parameters with different seeds" do
    model1 = described_class.new(data_array, **seeded_fit_options, seed: 12_345)
    model2 = described_class.new(data_array, **seeded_fit_options, seed: 54_321)

    expect(seeded_parameter_snapshot(model1, parameter_names)).not_to eq(
      seeded_parameter_snapshot(model2, parameter_names)
    )
  end

  it "does not reset or consume Ruby's global random number generator" do
    srand(98_765)
    expected_values = Array.new(5) { rand }

    srand(98_765)
    described_class.new(data_array, **seeded_fit_options, seed: 12_345)
    actual_values = Array.new(5) { rand }

    expect(actual_values).to eq(expected_values)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
