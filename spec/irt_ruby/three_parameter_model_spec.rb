# frozen_string_literal: true

require "spec_helper"

RSpec.describe IrtRuby::ThreeParameterModel do
  let(:data) { Matrix[[1, 0, 1], [0, 1, 0], [1, 1, 1]] }
  let(:model) { IrtRuby::ThreeParameterModel.new(data) }

  describe "#initialize" do
    it "initializes with data" do
      expect(model.instance_variable_get(:@data)).to eq(data)
    end
  end

  describe "#sigmoid" do
    it "calculates the sigmoid function" do
      expect(model.sigmoid(0)).to eq(0.5)
    end
  end

  describe "#probability" do
    it "calculates the probability with guessing parameter" do
      expect(model.probability(0, 1, 0, 0.2)).to be_within(0.01).of(0.6)
    end
  end

  describe "#likelihood" do
    it "calculates the likelihood of the data" do
      expect(model.likelihood).to be_a(Float)
    end
  end

  describe "#fit" do
    it "fits the model and returns abilities, difficulties, discriminations, and guessings" do
      result = model.fit
      expect(result[:abilities].size).to eq(data.row_count)
      expect(result[:difficulties].size).to eq(data.column_count)
      expect(result[:discriminations].size).to eq(data.column_count)
      expect(result[:guessings].size).to eq(data.column_count)
    end
  end
end
