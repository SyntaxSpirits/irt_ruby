# frozen_string_literal: true

require "spec_helper"

RSpec.describe IrtRuby::ThreeParameterModel do
  let(:data_array) do
    [
      [1, 1, 0],
      [1, 0, 1],
      [0, 1, 1],
      [1, 1, 1]
    ]
  end

  let(:data_matrix) { Matrix[*data_array] }

  describe "Basic fitting and improvement" do
    it "fits the 3PL model with an array-of-arrays and improves log-likelihood" do
      model = described_class.new(data_array, max_iter: 300, learning_rate: 0.1)
      initial_ll = model.log_likelihood
      results = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
      expect(results[:abilities].size).to eq(4)
      expect(results[:difficulties].size).to eq(3)
      expect(results[:discriminations].size).to eq(3)
      expect(results[:guessings].size).to eq(3)
    end

    it "fits the 3PL model with a Matrix and improves log-likelihood" do
      model = described_class.new(data_matrix, max_iter: 300, learning_rate: 0.1)
      initial_ll = model.log_likelihood
      results = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
      expect(results[:abilities].size).to eq(4)
      expect(results[:difficulties].size).to eq(3)
      expect(results[:discriminations].size).to eq(3)
      expect(results[:guessings].size).to eq(3)
    end
  end

  describe "Missing data handling" do
    it "handles nil entries gracefully without raising errors" do
      missing_data = [
        [1, nil, 0],
        [1,  0,   1],
        [0,  1,   nil],
        [1,  1,   1]
      ]
      model = described_class.new(missing_data, max_iter: 200, learning_rate: 0.05)
      expect { model.fit }.not_to raise_error

      results = model.fit
      expect(results[:abilities]).not_to be_empty
      expect(results[:difficulties]).not_to be_empty
      expect(results[:discriminations]).not_to be_empty
      expect(results[:guessings]).not_to be_empty
    end
  end

  describe "Missing data strategies" do
    let(:data_with_missing) do
      [
        [1, nil, 0],
        [nil, 0, 1]
      ]
    end

    it "ignores missing data by default" do
      model = IrtRuby::ThreeParameterModel.new(data_with_missing)
      expect { model.fit }.not_to raise_error
    end

    it "treats missing as incorrect" do
      model = IrtRuby::ThreeParameterModel.new(data_with_missing, missing_strategy: :treat_as_incorrect)
      expect { model.fit }.not_to raise_error
    end

    it "treats missing as correct" do
      model = IrtRuby::ThreeParameterModel.new(data_with_missing, missing_strategy: :treat_as_correct)
      expect { model.fit }.not_to raise_error
    end

    it "raises an error on invalid strategy" do
      expect do
        IrtRuby::ThreeParameterModel.new(data_with_missing, missing_strategy: :not_a_valid_strategy)
      end.to raise_error(ArgumentError)
    end
  end

  describe "Edge cases" do
    it "works with a single examinee and single item" do
      data = [[0]]
      model = described_class.new(data, max_iter: 100)
      expect { model.fit }.not_to raise_error

      results = model.fit
      expect(results[:abilities].size).to eq(1)
      expect(results[:difficulties].size).to eq(1)
      expect(results[:discriminations].size).to eq(1)
      expect(results[:guessings].size).to eq(1)
    end

    it "handles all responses correct" do
      data = [
        [1, 1],
        [1, 1]
      ]
      model = described_class.new(data, max_iter: 100)
      initial_ll = model.log_likelihood
      results = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be >= initial_ll
      expect(results[:abilities].size).to eq(2)
      expect(results[:difficulties].size).to eq(2)
      expect(results[:discriminations].size).to eq(2)
      expect(results[:guessings].size).to eq(2)
    end

    it "handles all responses incorrect" do
      data = [
        [0, 0],
        [0, 0]
      ]
      model = described_class.new(data, max_iter: 100)
      initial_ll = model.log_likelihood
      results = model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be >= initial_ll
      expect(results[:abilities].size).to eq(2)
      expect(results[:difficulties].size).to eq(2)
      expect(results[:discriminations].size).to eq(2)
      expect(results[:guessings].size).to eq(2)
    end

    it "handles an entire row missing" do
      data = [
        [1, 0],
        [nil, nil]
      ]
      model = described_class.new(data, max_iter: 200)
      expect { model.fit }.not_to raise_error

      results = model.fit
      expect(results[:abilities].size).to eq(2)
      expect(results[:difficulties].size).to eq(2)
      expect(results[:discriminations].size).to eq(2)
      expect(results[:guessings].size).to eq(2)
    end

    it "handles an entire column missing" do
      data = [
        [1,  nil, 0],
        [1,  nil, 1],
        [0,  nil, 1]
      ]
      model = described_class.new(data, max_iter: 200)
      expect { model.fit }.not_to raise_error

      results = model.fit
      expect(results[:abilities].size).to eq(3)
      expect(results[:difficulties].size).to eq(3)
      expect(results[:discriminations].size).to eq(3)
      expect(results[:guessings].size).to eq(3)
    end
  end

  describe "Hyperparameter extremes" do
    it "does not diverge with a large learning rate (but may revert updates)" do
      model = described_class.new(data_array, max_iter: 200, learning_rate: 5.0)
      expect { model.fit }.not_to raise_error

      results = model.fit
      expect(results[:abilities]).not_to be_empty
      expect(results[:difficulties]).not_to be_empty
      expect(results[:discriminations]).not_to be_empty
      expect(results[:guessings]).not_to be_empty
    end

    it "shows improvement with a very small learning rate" do
      model = described_class.new(data_array, max_iter: 2000, learning_rate: 1e-4)
      initial_ll = model.log_likelihood
      model.fit
      final_ll = model.log_likelihood

      expect(final_ll).to be > initial_ll
    end
  end

  describe "Additional tests" do
    context "Repeated fitting" do
      it "handles multiple calls to fit" do
        model = described_class.new(data_array, max_iter: 100)
        first_result = model.fit
        second_result = model.fit

        expect(second_result[:abilities].size).to eq(first_result[:abilities].size)
        expect(second_result[:difficulties].size).to eq(first_result[:difficulties].size)
        expect(second_result[:discriminations].size).to eq(first_result[:discriminations].size)
        expect(second_result[:guessings].size).to eq(first_result[:guessings].size)
      end
    end

    context "Deterministic seed" do
      it "produces consistent results with the same seed" do
        srand(123)
        model1 = described_class.new(data_array, max_iter: 200, learning_rate: 0.05)
        result1 = model1.fit

        srand(123)
        model2 = described_class.new(data_array, max_iter: 200, learning_rate: 0.05)
        result2 = model2.fit

        expect(result1[:abilities]).to eq(result2[:abilities])
        expect(result1[:difficulties]).to eq(result2[:difficulties])
        expect(result1[:discriminations]).to eq(result2[:discriminations])
        expect(result1[:guessings]).to eq(result2[:guessings])
      end
    end

    context "Larger random dataset" do
      it "handles a moderately large dataset without error" do
        n_examinees = 20
        n_items = 8
        big_data = Array.new(n_examinees) do
          Array.new(n_items) { rand < 0.5 ? 1 : 0 }
        end

        model = described_class.new(big_data, max_iter: 300, learning_rate: 0.05)
        expect { model.fit }.not_to raise_error

        results = model.fit
        expect(results[:abilities].size).to eq(n_examinees)
        expect(results[:difficulties].size).to eq(n_items)
        expect(results[:discriminations].size).to eq(n_items)
        expect(results[:guessings].size).to eq(n_items)
      end
    end

    context "Known parameter test (optional)" do
      it "attempts to recover small synthetic data parameters" do
        data = [
          [1, 1],
          [1, 1]
        ]

        model = described_class.new(data, max_iter: 200, learning_rate: 0.05)
        results = model.fit

        results[:discriminations].each do |disc|
          expect(disc).to be_between(0.01, 5.0)
        end
        results[:guessings].each do |g|
          expect(g).to be_between(0.0, 0.35)
        end
      end
    end
  end
end
