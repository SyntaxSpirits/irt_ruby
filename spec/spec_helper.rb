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
    expect { described_class.new([[1, 0], [1]]) }.to raise_error(ArgumentError, /rectangular/)
  end

  it "rejects invalid response values" do
    expect { described_class.new([[1, 2], [0, nil]]) }.to raise_error(ArgumentError, /invalid value 2/)
  end

  it "rejects float response values that compare equal to allowed integers" do
    expect { described_class.new([[0.0]]) }.to raise_error(ArgumentError, /invalid value 0\.0/)
    expect { described_class.new([[1.0]]) }.to raise_error(ArgumentError, /invalid value 1\.0/)
  end

  it "rejects non-numeric truthy, falsey, and string responses" do
    expect { described_class.new([[1, "1"], [false, nil]]) }.to raise_error(ArgumentError, /invalid value/)
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
