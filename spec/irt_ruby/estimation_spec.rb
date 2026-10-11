# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Estimation correctness" do
  models = {
    IrtRuby::RaschModel => %i[abilities difficulties],
    IrtRuby::TwoParameterModel => %i[abilities difficulties discriminations],
    IrtRuby::ThreeParameterModel => %i[abilities difficulties discriminations guessings]
  }

  def numeric_derivative(model, parameter, index, step = 1e-6)
    values = model.instance_variable_get("@#{parameter}")
    original = values[index]
    values[index] = original + step
    upper = model.log_likelihood
    values[index] = original - step
    lower = model.log_likelihood
    values[index] = original
    (upper - lower) / (2 * step)
  end

  def correlation(xs, ys)
    mean_x = xs.sum / xs.size
    mean_y = ys.sum / ys.size
    covariance = xs.zip(ys).sum { |x, y| (x - mean_x) * (y - mean_y) }
    covariance / Math.sqrt(xs.sum { |x| (x - mean_x)**2 } * ys.sum { |y| (y - mean_y)**2 })
  end

  def simulate(rng, abilities, difficulties, discriminations, guessings)
    abilities.map do |theta|
      difficulties.each_index.map do |j|
        prob = guessings[j] + ((1 - guessings[j]) / (1 + Math.exp(-discriminations[j] * (theta - difficulties[j]))))
        rng.rand < prob ? 1 : 0
      end
    end
  end

  let(:mixed_data) do
    rng = Random.new(7)
    Array.new(12) { Array.new(6) { [0, 1, 1, nil][rng.rand(4)] } }
  end

  models.each do |model_class, parameters|
    describe model_class do
      %i[ignore treat_as_incorrect treat_as_correct].each do |strategy|
        it "has analytic gradients matching finite differences with #{strategy}" do
          model = model_class.new(mixed_data, missing_strategy: strategy, seed: 3)
          gradients = model.compute_gradient

          parameters.each_with_index do |parameter, n|
            gradients[n].each_index do |k|
              next if gradients[n][k].zero? && numeric_derivative(model, parameter, k).zero?

              expect(gradients[n][k]).to be_within(1e-5).of(numeric_derivative(model, parameter, k))
            end
          end
        end
      end

      it "returns nil for persons and items with extreme or unobserved responses" do
        data = [
          [1, 0, 1, 1, nil],
          [0, 1, 0, 1, nil],
          [1, 1, 0, 1, nil],
          [1, 1, 1, 1, nil],
          [0, 0, 0, 1, nil],
          [nil, nil, nil, nil, nil]
        ]
        results = model_class.new(data, seed: 1).fit

        expect(results[:abilities].map(&:nil?)).to eq([false, false, false, true, true, true])
        expect(results[:difficulties].map(&:nil?)).to eq([false, false, false, true, true])
      end

      it "repeats exclusion when dropping items makes a person extreme" do
        data = [
          [1, 1, 0],
          [1, 0, 0],
          [0, 1, 0]
        ]
        results = model_class.new(data, seed: 1).fit

        expect(results[:difficulties].map(&:nil?)).to eq([false, false, true])
        expect(results[:abilities].map(&:nil?)).to eq([true, false, false])
      end

      it "fixes the latent scale of the returned abilities" do
        rng = Random.new(11)
        data = simulate(rng, Array.new(60) { (rng.rand * 4) - 2 }, Array.new(8) { (rng.rand * 2) - 1 },
                        Array.new(8, 1.0), Array.new(8, 0.0))
        abilities = model_class.new(data, max_iter: 50, seed: 1).fit[:abilities].compact
        mean, sd = IrtRuby::Estimation.mean_and_sd(abilities)

        expect(mean).to be_within(1e-12).of(0.0)
        expect(sd).to be_within(1e-12).of(1.0) unless model_class == IrtRuby::RaschModel
      end

      it "keeps the likelihood unchanged when fixing the scale" do
        model = model_class.new(mixed_data, max_iter: 1, seed: 1)
        model.instance_variable_set(:@max_iter, 0)
        before = model.log_likelihood
        model.fit

        expect(model.log_likelihood).to be_within(1e-9).of(before)
      end

      it "does not report convergence when the learning rate is too small to move" do
        results = model_class.new(mixed_data, learning_rate: 1e-20, seed: 1).fit

        expect(results[:converged]).to be(false)
        expect(results[:iterations]).to eq(1)
      end

      it "reports exhausting max_iter as not converged" do
        results = model_class.new(mixed_data, max_iter: 3, seed: 1).fit

        expect(results).to include(converged: false, iterations: 3)
      end

      it "evaluates badly mispredicted responses without saturating the likelihood" do
        model = model_class.new([[0, 1], [1, 0]], seed: 1)
        model.instance_variable_set(:@abilities, [40.0, 0.0])
        model.instance_variable_set(:@difficulties, [0.0, 0.0])
        model.instance_variable_set(:@discriminations, [1.0, 1.0]) if parameters.include?(:discriminations)
        model.instance_variable_set(:@guessings, [0.0, 0.0]) if parameters.include?(:guessings)

        expect(model.log_likelihood).to be_within(1e-9).of(-40.0 - (2 * Math.log(2)))
      end

      it "is not affected by later changes to the input or the returned arrays" do
        data = [[1, 0], [0, 1]]
        model = model_class.new(data, max_iter: 5, seed: 1)
        data[0] << 1
        results = model.fit
        before = model.log_likelihood
        results[:abilities][0] = 100.0

        expect(model.log_likelihood).to eq(before)
      end
    end
  end

  it "reaches the exact Rasch joint estimates on the README data" do
    results = IrtRuby::RaschModel.new([[1, 0, 1], [0, 1, 0], [1, 1, 1]], learning_rate: 0.5, seed: 1).fit

    expect(results[:converged]).to be(true)
    expect(results[:abilities][0]).to be_within(1e-3).of(Math.log(2))
    expect(results[:abilities][1]).to be_within(1e-3).of(-Math.log(2))
    expect(results[:abilities][2]).to be_nil
    results[:difficulties].each { |b| expect(b).to be_within(1e-3).of(0.0) }
  end

  it "recovers simulated Rasch difficulties" do
    rng = Random.new(42)
    difficulties = Array.new(10) { (rng.rand * 3) - 1.5 }
    data = simulate(rng, Array.new(300) { (rng.rand * 4) - 2 }, difficulties, Array.new(10, 1.0), Array.new(10, 0.0))
    results = IrtRuby::RaschModel.new(data, learning_rate: 0.05, seed: 1).fit

    expect(results[:converged]).to be(true)
    expect(correlation(difficulties, results[:difficulties])).to be > 0.97
  end

  it "recovers simulated 2PL difficulties and discriminations" do
    rng = Random.new(42)
    difficulties = Array.new(10) { (rng.rand * 3) - 1.5 }
    discriminations = Array.new(10) { 0.6 + (rng.rand * 1.4) }
    data = simulate(rng, Array.new(300) { (rng.rand * 4) - 2 }, difficulties, discriminations, Array.new(10, 0.0))
    results = IrtRuby::TwoParameterModel.new(data, learning_rate: 0.05, max_iter: 500, seed: 1).fit

    expect(correlation(difficulties, results[:difficulties])).to be > 0.95
    expect(correlation(discriminations, results[:discriminations])).to be > 0.7
  end
end
