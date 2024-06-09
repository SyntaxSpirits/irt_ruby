# frozen_string_literal: true

require "irt_ruby"

RSpec.describe IrtRuby::RaschModel do
  let(:data) { Matrix[[1, 0, 1], [0, 1, 0], [1, 1, 1]] }
  let(:irt_model) { IrtRuby::RaschModel.new(data) }

  describe "#sigmoid" do
    it "calculates the sigmoid of a value" do
      expect(irt_model.sigmoid(0)).to be_within(0.01).of(0.5)
      expect(irt_model.sigmoid(2)).to be_within(0.01).of(0.88)
    end
  end

  describe "#likelihood" do
    it "calculates the likelihood of the data" do
      expect(irt_model.likelihood).to be_a(Float)
    end
  end

  describe "#fit" do
    it "fits the model and returns abilities and difficulties" do
      results = irt_model.fit
      expect(results[:abilities].size).to eq(3)
      expect(results[:difficulties].size).to eq(3)
    end
  end
end
