# frozen_string_literal: true

require "spec_helper"
require "matrix"

RSpec.describe "README examples" do
  let(:data) do
    Matrix[
      [1, 0, 1],
      [0, 1, 0],
      [1, 1, 1]
    ]
  end

  it "runs the Rasch quick-start example" do
    model = IrtRuby::RaschModel.new(data)
    result = model.fit

    expect(result[:abilities].size).to eq(data.row_count)
    expect(result[:difficulties].size).to eq(data.column_count)
  end

  it "runs the 2PL and 3PL examples" do
    two_pl_result = IrtRuby::TwoParameterModel.new(data).fit
    three_pl_result = IrtRuby::ThreeParameterModel.new(data).fit

    expect(two_pl_result[:abilities].size).to eq(data.row_count)
    expect(two_pl_result[:difficulties].size).to eq(data.column_count)
    expect(two_pl_result[:discriminations].size).to eq(data.column_count)

    expect(three_pl_result[:abilities].size).to eq(data.row_count)
    expect(three_pl_result[:difficulties].size).to eq(data.column_count)
    expect(three_pl_result[:discriminations].size).to eq(data.column_count)
    expect(three_pl_result[:guessings].size).to eq(data.column_count)
  end

  it "runs the missing-data example with array input" do
    data_with_missing = [
      [1, nil, 0],
      [nil, 1, 0],
      [0, 1, 1]
    ]

    model = IrtRuby::RaschModel.new(
      data_with_missing,
      max_iter: 300,
      learning_rate: 0.01,
      missing_strategy: :treat_as_incorrect
    )
    result = model.fit

    expect(result[:abilities].size).to eq(data_with_missing.size)
    expect(result[:difficulties].size).to eq(data_with_missing.first.size)
  end
end
