# frozen_string_literal: true

require "json"

module IrtRuby
  # An immutable set of calibrated items that can be stored as JSON and reused
  # without recalibrating. Parameters use the logistic metric with no scaling
  # constant: P(correct | theta) = c + (1 - c) / (1 + exp(-a * (theta - b))).
  class ItemBank
    include Enumerable

    FORMAT = "irt_ruby.item_bank"
    FORMAT_VERSION = 1
    MODELS = %w[rasch 2pl 3pl].freeze

    Item = Struct.new(:id, :a, :b, :c)

    attr_reader :model, :metadata

    # Builds a bank from a model's fit results. Items whose parameters are nil
    # raise unless exclude_unestimated is true, in which case their ids are
    # recorded in the metadata under "unestimated_items".
    def self.from_fit(results, item_ids:, metadata: {}, exclude_unestimated: false)
      model = if results.key?(:guessings)
                "3pl"
              elsif results.key?(:discriminations)
                "2pl"
              else
                "rasch"
              end
      difficulties = results.fetch(:difficulties)
      raise ArgumentError, "item_ids must be an Array with one id per item (#{difficulties.size})" unless item_ids.is_a?(Array) && item_ids.size == difficulties.size

      unestimated = item_ids.select.with_index { |_, j| difficulties[j].nil? }
      raise ArgumentError, "items without estimates: #{unestimated.join(", ")}; pass exclude_unestimated: true to leave them out" unless unestimated.empty? || exclude_unestimated

      items = item_ids.each_index.reject { |j| difficulties[j].nil? }.map do |j|
        { id: item_ids[j], a: results.fetch(:discriminations, nil)&.at(j) || 1.0,
          b: difficulties[j], c: results.fetch(:guessings, nil)&.at(j) || 0.0 }
      end

      provenance = {
        "software" => "irt_ruby #{VERSION}",
        "estimation" => "joint maximum likelihood",
        "scale" => model == "rasch" ? "abilities centered at 0" : "abilities standardized to mean 0, SD 1",
        "converged" => results[:converged],
        "iterations" => results[:iterations]
      }
      provenance["unestimated_items"] = unestimated unless unestimated.empty?

      new(model: model, items: items, metadata: provenance.merge(metadata.transform_keys(&:to_s)))
    end

    def self.from_json(json)
      from_h(JSON.parse(json))
    end

    def self.from_h(hash)
      raise ArgumentError, "item bank must be a Hash" unless hash.is_a?(Hash)
      raise ArgumentError, "not an item bank: format must be #{FORMAT.inspect}" unless hash["format"] == FORMAT

      version = hash["format_version"]
      raise ArgumentError, "unsupported item bank format_version #{version.inspect}; this irt_ruby reads #{FORMAT_VERSION}" unless version == FORMAT_VERSION

      new(model: hash["model"], items: hash["items"], metadata: hash.fetch("metadata", {}))
    end

    # items: an Array of Hashes with an "id" (String) and "b", plus "a" (2PL/3PL)
    # and "c" (3PL); string or symbol keys. metadata must be JSON-serializable.
    def initialize(model:, items:, metadata: {})
      raise ArgumentError, "model must be one of #{MODELS}" unless MODELS.include?(model)
      raise ArgumentError, "items must be a non-empty Array" unless items.is_a?(Array) && !items.empty?
      raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)

      @model = model
      @items = items.each_with_index.map { |item, index| build_item(item, index) }.freeze
      @index = @items.each_with_index.to_h { |item, k| [item.id, k] }.freeze
      raise ArgumentError, "item ids must be unique" unless @index.size == @items.size

      @metadata = deep_freeze(normalize_metadata(metadata))
      freeze
    end

    def each(&block)
      return enum_for(:each) unless block

      @items.each(&block)
      self
    end

    def size
      @items.size
    end

    def ids
      @items.map(&:id)
    end

    def [](id)
      position = @index[id]
      position && @items[position]
    end

    def fetch(id)
      self[id] || raise(KeyError, "unknown item id #{id.inspect}")
    end

    def probability(id, theta)
      item = fetch(id)
      item.c + ((1.0 - item.c) / (1.0 + Math.exp(-item.a * (theta - item.b))))
    end

    def to_h
      {
        "format" => FORMAT,
        "format_version" => FORMAT_VERSION,
        "model" => @model,
        "metadata" => @metadata,
        "items" => @items.map { |item| { "id" => item.id, "a" => item.a, "b" => item.b, "c" => item.c } }
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def ==(other)
      other.is_a?(ItemBank) && to_h == other.to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    private

    def build_item(item, index)
      raise ArgumentError, "item #{index + 1} must be a Hash" unless item.is_a?(Hash)

      id = value(item, :id)
      raise ArgumentError, "item #{index + 1} id must be a non-empty String" unless id.is_a?(String) && !id.empty?

      b = number(item, :b, id, required: true)
      a = number(item, :a, id, required: @model != "rasch")
      c = number(item, :c, id, required: @model == "3pl")
      a = validate_discrimination(a, id)
      c = validate_guessing(c, id)

      Item.new(id.dup.freeze, a, b, c).freeze
    end

    def validate_discrimination(a, id)
      return 1.0 if a.nil?
      raise ArgumentError, "item #{id.inspect}: rasch items must have a = 1" if @model == "rasch" && (a - 1.0).abs > 1e-9
      raise ArgumentError, "item #{id.inspect}: a must be positive" unless a.positive?

      a
    end

    def validate_guessing(c, id)
      return 0.0 if c.nil?
      raise ArgumentError, "item #{id.inspect}: #{@model} items must have c = 0" if @model != "3pl" && !c.zero?
      raise ArgumentError, "item #{id.inspect}: c must be in [0, 1)" unless c >= 0 && c < 1

      c
    end

    def number(item, key, id, required:)
      raw = value(item, key)
      return nil if raw.nil? && !required
      raise ArgumentError, "item #{id.inspect}: #{key} must be a finite number" unless raw.is_a?(Numeric) && !raw.is_a?(Complex) && raw.finite?

      raw.to_f
    end

    def value(item, key)
      item.key?(key) ? item[key] : item[key.to_s]
    end

    def normalize_metadata(metadata)
      JSON.parse(JSON.generate(metadata))
    rescue JSON::GeneratorError => e
      raise ArgumentError, "metadata must be JSON-serializable: #{e.message}"
    end

    def deep_freeze(object)
      case object
      when Hash then object.each_value { |v| deep_freeze(v) }
      when Array then object.each { |v| deep_freeze(v) }
      end
      object.freeze
    end
  end
end
