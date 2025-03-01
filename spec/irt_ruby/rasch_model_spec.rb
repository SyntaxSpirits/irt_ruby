# frozen_string_literal: true

require "spec_helper"

RSpec.describe IrtRuby::RaschModel do
  let(:data_array) do
    [
      [1, 1, 0],
      [1, 0, 0],
      [0, 1, 1]
    ]
  end

  let(:data_matrix) { Matrix[*data_array] }

  describe "Basic fitting and improvement" do
    it "fits the model on an array-of-arrays dataset and improves log-likelihood" do
      model = described_class.new(data_array, max_iter: 300, learning_rate: 0.1)
      initial_ll = model.log_likelihood
      result = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
      expect(result[:abilities].size).to eq(3)
      expect(result[:difficulties].size).to eq(3)
    end

    it "fits the model on a Matrix dataset and improves log-likelihood" do
      model = described_class.new(data_matrix, max_iter: 300, learning_rate: 0.1)
      initial_ll = model.log_likelihood
      result = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
      expect(result[:abilities].size).to eq(3)
      expect(result[:difficulties].size).to eq(3)
    end
  end

  describe "Missing data" do
    it "handles missing entries (nil) gracefully" do
      missing_data = [
        [1, nil, 0],
        [nil, 0, 0],
        [0, 1, 1]
      ]
      model = described_class.new(missing_data, max_iter: 200, learning_rate: 0.05)

      expect { model.fit }.not_to raise_error
      result = model.fit
      expect(result[:abilities]).not_to be_empty
      expect(result[:difficulties]).not_to be_empty
    end
  end

  describe "Edge cases" do
    it "works with a single examinee and single item" do
      data = [[1]]
      model = described_class.new(data, max_iter: 100)
      expect { model.fit }.not_to raise_error

      result = model.fit
      expect(result[:abilities].size).to eq(1)
      expect(result[:difficulties].size).to eq(1)
    end

    it "works with all responses correct" do
      data = [
        [1, 1],
        [1, 1]
      ]
      model = described_class.new(data, max_iter: 100)
      initial_ll = model.log_likelihood
      result = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be >= initial_ll
      expect(result[:abilities].size).to eq(2)
      expect(result[:difficulties].size).to eq(2)
    end

    it "works with all responses incorrect" do
      data = [
        [0, 0],
        [0, 0]
      ]
      model = described_class.new(data, max_iter: 100)
      initial_ll = model.log_likelihood
      result = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be >= initial_ll
      expect(result[:abilities].size).to eq(2)
      expect(result[:difficulties].size).to eq(2)
    end

    it "handles an entire row missing" do
      data = [
        [1, 0, 1],
        [nil, nil, nil]
      ]
      model = described_class.new(data)
      expect { model.fit }.not_to raise_error
      expect(model.fit[:abilities].size).to eq(2)
      expect(model.fit[:difficulties].size).to eq(3)
    end

    it "handles an entire column missing" do
      data = [
        [1, nil, 0],
        [1, nil, 0]
      ]
      model = described_class.new(data)
      expect { model.fit }.not_to raise_error
      expect(model.fit[:abilities].size).to eq(2)
      expect(model.fit[:difficulties].size).to eq(3)
    end
  end

  describe "Hyperparameter extremes" do
    it "does not diverge with a large learning rate (but may revert updates)" do
      model = described_class.new(data_array, max_iter: 200, learning_rate: 5.0)
      expect { model.fit }.not_to raise_error

      result = model.fit
      expect(result[:abilities]).not_to be_empty
      expect(result[:difficulties]).not_to be_empty
    end

    it "still improves log-likelihood with a very small learning rate" do
      model = described_class.new(data_array, max_iter: 2000, learning_rate: 1e-4)
      initial_ll = model.log_likelihood
      model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
    end
  end
end
