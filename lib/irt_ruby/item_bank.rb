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
    ESTIMATED_PARAMETERS = {
      "rasch" => %i[difficulties],
      "2pl" => %i[difficulties discriminations],
      "3pl" => %i[difficulties discriminations guessings]
    }.freeze

    Item = Struct.new(:id, :a, :b, :c)

    # ability_distribution is the mean and SD of abilities in the calibration
    # population on the bank's scale, or nil when unknown.
    attr_reader :model, :ability_distribution, :metadata

    # Builds a bank from a model's fit results. Items with a nil parameter raise
    # unless exclude_unestimated is true, in which case their ids are recorded in
    # the metadata under "unestimated_items".
    def self.from_fit(results, item_ids:, metadata: {}, exclude_unestimated: false)
      raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)

      model = if results.key?(:guessings)
                "3pl"
              elsif results.key?(:discriminations)
                "2pl"
              else
                "rasch"
              end
      parameters = ESTIMATED_PARAMETERS.fetch(model).to_h do |key|
        [key, results.fetch(key) { raise ArgumentError, "#{model} fit results must include #{key}" }]
      end
      validate_fit_ids!(item_ids, parameters)

      unestimated = item_ids.select.with_index { |_, j| parameters.values.any? { |values| values[j].nil? } }
      raise ArgumentError, "items without estimates: #{unestimated.join(", ")}; pass exclude_unestimated: true to leave them out" unless unestimated.empty? || exclude_unestimated

      items = item_ids.each_index.reject { |j| unestimated.include?(item_ids[j]) }.map do |j|
        { id: item_ids[j], b: parameters[:difficulties][j],
          a: parameters.key?(:discriminations) ? parameters[:discriminations][j] : 1.0,
          c: parameters.key?(:guessings) ? parameters[:guessings][j] : 0.0 }
      end

      provenance = {
        "software" => "irt_ruby #{VERSION}",
        "estimation" => "joint maximum likelihood",
        "scale" => model == "rasch" ? "abilities centered at 0" : "abilities standardized to mean 0, SD 1",
        "converged" => results[:converged],
        "iterations" => results[:iterations]
      }
      provenance["unestimated_items"] = unestimated unless unestimated.empty?

      new(model: model, items: items, ability_distribution: sample_distribution(results[:abilities]),
          metadata: provenance.merge(metadata.transform_keys(&:to_s)))
    end

    def self.validate_fit_ids!(item_ids, parameters)
      raise ArgumentError, "difficulties must be an Array" unless parameters[:difficulties].is_a?(Array)

      count = parameters[:difficulties].size
      raise ArgumentError, "item_ids must be an Array with one id per item (#{count})" unless item_ids.is_a?(Array) && item_ids.size == count

      parameters.each do |key, values|
        raise ArgumentError, "#{key} must be an Array with one value per item (#{count})" unless values.is_a?(Array) && values.size == count
      end
      item_ids.each_with_index do |id, j|
        raise ArgumentError, "item #{j + 1} id must be a non-empty String" unless id.is_a?(String) && !id.empty?
      end
      raise ArgumentError, "item ids must be unique" unless item_ids.uniq.size == count
    end
    private_class_method :validate_fit_ids!

    def self.sample_distribution(abilities)
      values = Array(abilities).compact
      raise ArgumentError, "abilities must be finite numbers or nil" unless values.all? { |v| v.is_a?(Numeric) && !v.is_a?(Complex) && v.to_f.finite? }

      values = values.map(&:to_f)
      return nil if values.size < 2

      mean = values.sum / values.size
      sd = Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size)
      sd.positive? ? { "mean" => mean, "sd" => sd } : nil
    end
    private_class_method :sample_distribution

    def self.from_json(json)
      from_h(JSON.parse(json))
    end

    def self.from_h(hash)
      raise ArgumentError, "item bank must be a Hash" unless hash.is_a?(Hash)
      raise ArgumentError, "not an item bank: format must be #{FORMAT.inspect}" unless hash["format"] == FORMAT

      version = hash["format_version"]
      raise ArgumentError, "unsupported item bank format_version #{version.inspect}; this irt_ruby reads #{FORMAT_VERSION}" unless version == FORMAT_VERSION

      new(model: hash["model"], items: hash["items"], ability_distribution: hash["ability_distribution"],
          metadata: hash.fetch("metadata", {}))
    end

    # items: an Array of Hashes with an "id" (String) and "b", plus "a" (2PL/3PL)
    # and "c" (3PL); string or symbol keys. ability_distribution: nil or a Hash
    # with "mean" and "sd". metadata must be JSON-serializable.
    def initialize(model:, items:, ability_distribution: nil, metadata: {})
      @model = MODELS.find { |name| name == model }
      raise ArgumentError, "model must be one of #{MODELS}" unless @model
      raise ArgumentError, "items must be a non-empty Array" unless items.is_a?(Array) && !items.empty?
      raise ArgumentError, "metadata must be a Hash" unless metadata.is_a?(Hash)

      @items = items.each_with_index.map { |item, index| build_item(item, index) }.freeze
      @index = @items.each_with_index.to_h { |item, k| [item.id, k] }.freeze
      raise ArgumentError, "item ids must be unique" unless @index.size == @items.size

      @ability_distribution = build_distribution(ability_distribution)
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
      hash = { "format" => FORMAT, "format_version" => FORMAT_VERSION, "model" => @model }
      hash["ability_distribution"] = @ability_distribution if @ability_distribution
      hash["metadata"] = @metadata
      hash["items"] = @items.map { |item| { "id" => item.id, "a" => item.a, "b" => item.b, "c" => item.c } }
      hash
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def ==(other)
      other.is_a?(ItemBank) && to_h == other.to_h
    end

    def eql?(other)
      other.is_a?(ItemBank) && to_h.eql?(other.to_h)
    end

    def hash
      to_h.hash
    end

    private

    def build_item(item, index)
      raise ArgumentError, "item #{index + 1} must be a Hash" unless item.is_a?(Hash)

      id = value(item, :id)
      raise ArgumentError, "item #{index + 1} id must be a non-empty String" unless id.is_a?(String) && !id.empty?

      label = "item #{id.inspect}"
      b = number(value(item, :b), "#{label}: b", required: true)
      a = number(value(item, :a), "#{label}: a", required: @model != "rasch")
      c = number(value(item, :c), "#{label}: c", required: @model == "3pl")

      Item.new(id.dup.freeze, discrimination(a, label), b, guessing(c, label)).freeze
    end

    def discrimination(a, label)
      return 1.0 if a.nil?

      if @model == "rasch"
        raise ArgumentError, "#{label}: rasch items must have a = 1" if (a - 1.0).abs > 1e-9

        return 1.0
      end
      raise ArgumentError, "#{label}: a must be positive" unless a.positive?

      a
    end

    def guessing(c, label)
      return 0.0 if c.nil?
      raise ArgumentError, "#{label}: #{@model} items must have c = 0" if @model != "3pl" && !c.zero?
      raise ArgumentError, "#{label}: c must be in [0, 1)" unless c >= 0 && c < 1

      c
    end

    def build_distribution(distribution)
      return nil if distribution.nil?
      raise ArgumentError, "ability_distribution must be a Hash with mean and sd" unless distribution.is_a?(Hash)

      mean = number(value(distribution, :mean), "ability_distribution mean", required: true)
      sd = number(value(distribution, :sd), "ability_distribution sd", required: true)
      raise ArgumentError, "ability_distribution sd must be positive" unless sd.positive?

      { "mean" => mean, "sd" => sd }.freeze
    end

    def number(raw, label, required:)
      return nil if raw.nil? && !required

      converted = raw.to_f if raw.is_a?(Numeric) && !raw.is_a?(Complex)
      raise ArgumentError, "#{label} must be a finite number" unless converted&.finite?

      converted
    end

    def value(hash, key)
      hash.key?(key) ? hash[key] : hash[key.to_s]
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
