# frozen_string_literal: true

require "spec_helper"

RSpec.describe IrtRuby::ItemBank do
  let(:data) do
    rng = Random.new(3)
    Array.new(60) { Array.new(4) { rng.rand < 0.55 ? 1 : 0 } }
  end
  let(:item_ids) { %w[q1 q2 q3 q4] }

  let(:items_3pl) do
    [
      { "id" => "q1", "a" => 1.2, "b" => -0.5, "c" => 0.2 },
      { "id" => "q2", "a" => 0.8, "b" => 0.75, "c" => 0.0 }
    ]
  end

  describe ".from_fit" do
    {
      IrtRuby::RaschModel => "rasch",
      IrtRuby::TwoParameterModel => "2pl",
      IrtRuby::ThreeParameterModel => "3pl"
    }.each do |model_class, model_name|
      it "builds a #{model_name} bank keyed by item id" do
        results = model_class.new(data, max_iter: 50, seed: 1).fit
        bank = described_class.from_fit(results, item_ids: item_ids)

        expect(bank.model).to eq(model_name)
        expect(bank.ids).to eq(item_ids)
        item_ids.each_with_index do |id, j|
          item = bank.fetch(id)
          expect(item.b).to eq(results[:difficulties][j])
          expect(item.a).to eq(results.fetch(:discriminations, Array.new(4, 1.0))[j])
          expect(item.c).to eq(results.fetch(:guessings, Array.new(4, 0.0))[j])
        end
      end
    end

    it "records calibration provenance and merges caller metadata" do
      results = IrtRuby::RaschModel.new(data, max_iter: 5, seed: 1).fit
      bank = described_class.from_fit(results, item_ids: item_ids, metadata: { source: "pilot 2026", software: "custom" })

      expect(bank.metadata).to include(
        "software" => "custom",
        "estimation" => "joint maximum likelihood",
        "scale" => "abilities centered at 0",
        "converged" => results[:converged],
        "iterations" => 5,
        "source" => "pilot 2026"
      )
    end

    it "rejects items without estimates unless asked to exclude them" do
      results = IrtRuby::RaschModel.new([[1, 0, 1], [0, 1, 1]], seed: 1).fit

      expect { described_class.from_fit(results, item_ids: %w[a b c]) }
        .to raise_error(ArgumentError, /items without estimates: c/)

      bank = described_class.from_fit(results, item_ids: %w[a b c], exclude_unestimated: true)
      expect(bank.ids).to eq(%w[a b])
      expect(bank.metadata["unestimated_items"]).to eq(%w[c])
    end

    it "requires one id per item" do
      results = IrtRuby::RaschModel.new(data, max_iter: 5, seed: 1).fit

      expect { described_class.from_fit(results, item_ids: %w[q1 q2]) }.to raise_error(ArgumentError, /one id per item \(4\)/)
    end
  end

  describe "JSON" do
    it "round-trips every model exactly" do
      [IrtRuby::RaschModel, IrtRuby::TwoParameterModel, IrtRuby::ThreeParameterModel].each do |model_class|
        bank = described_class.from_fit(model_class.new(data, max_iter: 50, seed: 1).fit, item_ids: item_ids)
        restored = described_class.from_json(bank.to_json)

        expect(restored).to eq(bank)
        expect(restored.map(&:b)).to eq(bank.map(&:b))
      end
    end

    it "writes the format header, model, metadata, and items" do
      bank = described_class.new(model: "3pl", items: items_3pl, metadata: { "source" => "test" })

      expect(JSON.parse(JSON.generate(bank))).to eq(
        "format" => "irt_ruby.item_bank",
        "format_version" => 1,
        "model" => "3pl",
        "metadata" => { "source" => "test" },
        "items" => items_3pl
      )
    end

    it "fills in fixed parameters for rasch and 2pl items" do
      bank = described_class.from_json(
        '{"format":"irt_ruby.item_bank","format_version":1,"model":"rasch","items":[{"id":"x","b":0.5}]}'
      )

      expect(bank.fetch("x").to_a).to eq(["x", 1.0, 0.5, 0.0])
      expect(bank.metadata).to eq({})
    end

    it "rejects documents that are not item banks" do
      expect { described_class.from_json('{"format":"other","format_version":1}') }
        .to raise_error(ArgumentError, /not an item bank/)
      expect { described_class.from_json("[1]") }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "rejects unsupported format versions" do
      json = { "format" => "irt_ruby.item_bank", "format_version" => 2, "model" => "rasch", "items" => [] }.to_json

      expect { described_class.from_json(json) }.to raise_error(ArgumentError, /unsupported item bank format_version 2/)
    end
  end

  describe "validation" do
    def build(model, items)
      described_class.new(model: model, items: items)
    end

    it "accepts symbol keys" do
      expect(build("2pl", [{ id: "x", a: 1, b: 0 }]).fetch("x").to_a).to eq(["x", 1.0, 0.0, 0.0])
    end

    {
      "an unknown model" => ["4pl", [{ "id" => "x", "b" => 0 }], /model must be one of/],
      "an empty item list" => ["rasch", [], /non-empty Array/],
      "a missing id" => ["rasch", [{ "b" => 0 }], /item 1 id must be a non-empty String/],
      "a non-string id" => ["rasch", [{ "id" => 7, "b" => 0 }], /item 1 id must be a non-empty String/],
      "duplicate ids" => ["rasch", [{ "id" => "x", "b" => 0 }, { "id" => "x", "b" => 1 }], /ids must be unique/],
      "a missing difficulty" => ["rasch", [{ "id" => "x" }], /"x": b must be a finite number/],
      "a non-numeric difficulty" => ["rasch", [{ "id" => "x", "b" => "0" }], /b must be a finite number/],
      "an infinite difficulty" => ["rasch", [{ "id" => "x", "b" => Float::INFINITY }], /b must be a finite number/],
      "a rasch discrimination other than 1" => ["rasch", [{ "id" => "x", "a" => 1.5, "b" => 0 }], /rasch items must have a = 1/],
      "a missing 2pl discrimination" => ["2pl", [{ "id" => "x", "b" => 0 }], /a must be a finite number/],
      "a non-positive discrimination" => ["2pl", [{ "id" => "x", "a" => 0, "b" => 0 }], /a must be positive/],
      "a 2pl guessing parameter" => ["2pl", [{ "id" => "x", "a" => 1, "b" => 0, "c" => 0.1 }], /2pl items must have c = 0/],
      "a missing 3pl guessing parameter" => ["3pl", [{ "id" => "x", "a" => 1, "b" => 0 }], /c must be a finite number/],
      "a guessing parameter of 1" => ["3pl", [{ "id" => "x", "a" => 1, "b" => 0, "c" => 1 }], /c must be in \[0, 1\)/],
      "a negative guessing parameter" => ["3pl", [{ "id" => "x", "a" => 1, "b" => 0, "c" => -0.1 }], /c must be in \[0, 1\)/]
    }.each do |description, (model, items, message)|
      it "rejects #{description}" do
        expect { build(model, items) }.to raise_error(ArgumentError, message)
      end
    end

    it "rejects metadata that cannot be written as JSON" do
      expect { described_class.new(model: "rasch", items: [{ "id" => "x", "b" => 0 }], metadata: { "x" => Float::NAN }) }
        .to raise_error(ArgumentError, /metadata must be JSON-serializable/)
    end
  end

  describe "immutability" do
    it "is not affected by later changes to its inputs" do
      items = [{ "id" => +"x", "a" => 1.0, "b" => 0.0, "c" => 0.1 }]
      metadata = { "notes" => [+"first"] }
      bank = described_class.new(model: "3pl", items: items, metadata: metadata)
      items[0]["b"] = 5.0
      items[0]["id"] << "y"
      metadata["notes"] << "second"

      expect(bank.fetch("x").b).to eq(0.0)
      expect(bank.metadata).to eq("notes" => ["first"])
    end

    it "freezes the bank, its items, and its metadata" do
      bank = described_class.new(model: "3pl", items: items_3pl, metadata: { "notes" => ["first"] })

      expect(bank).to be_frozen
      expect(bank.first).to be_frozen
      expect(bank.first.id).to be_frozen
      expect(bank.metadata["notes"]).to be_frozen
    end
  end

  describe "lookup and probabilities" do
    let(:bank) { described_class.new(model: "3pl", items: items_3pl) }

    it "looks items up by id" do
      expect(bank.size).to eq(2)
      expect(bank["q2"].a).to eq(0.8)
      expect(bank["missing"]).to be_nil
      expect { bank.fetch("missing") }.to raise_error(KeyError, /unknown item id "missing"/)
    end

    it "computes the logistic response probability without a scaling constant" do
      expect(bank.probability("q1", 0.3)).to be_within(1e-15).of(0.2 + (0.8 / (1 + Math.exp(-1.2 * (0.3 - -0.5)))))
      expect(bank.probability("q2", 0.75)).to eq(0.5)
    end

    it "matches the probabilities of the model it was calibrated with" do
      model = IrtRuby::ThreeParameterModel.new(data, max_iter: 50, seed: 1)
      results = model.fit
      bank = described_class.from_fit(results, item_ids: item_ids)
      theta = results[:abilities].compact.first

      item_ids.each_with_index do |id, j|
        expected = model.probability(theta, results[:discriminations][j], results[:difficulties][j], results[:guessings][j])
        expect(bank.probability(id, theta)).to be_within(1e-15).of(expected)
      end
    end
  end
end
