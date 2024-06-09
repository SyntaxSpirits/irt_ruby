# frozen_string_literal: true

require "spec_helper"

RSpec.describe IrtRuby::RaschModel do
  let(:data) { Matrix[[1, 0, 1], [0, 1, 0], [1, 1, 1]] }
  let(:model) { IrtRuby::RaschModel.new(data, max_iter: 2000) }

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

  describe "#likelihood" do
    it "calculates the likelihood of the data" do
      expect(model.likelihood).to be_a(Float)
    end
  end

  describe "#fit" do
    it "fits the model and returns abilities and difficulties" do
      result = model.fit
      expect(result[:abilities].size).to eq(data.row_count)
      expect(result[:difficulties].size).to eq(data.column_count)
    end
  end
end
