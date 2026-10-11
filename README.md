# IrtRuby

IrtRuby is a Ruby gem that provides implementations of the **Rasch model**, the **Two-Parameter (2PL)** model, and the **Three-Parameter (3PL)** model for Item Response Theory (IRT). It allows you to estimate the **abilities** of individuals and the **difficulties** (and optionally **discriminations** and **guessing** parameters) of items based on their responses.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'irt_ruby'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install irt_ruby
```

## Usage

Here's a quick example using the Rasch model:

```ruby
require 'irt_ruby'
require 'matrix'

# Create a sample response matrix
data = Matrix[
  [1, 0, 1],
  [0, 1, 0],
  [1, 1, 1]
]

# Initialize the Rasch model with the response data
model = IrtRuby::RaschModel.new(data)

# Fit the model to estimate abilities and difficulties
result = model.fit

# Output the estimated abilities and difficulties
puts "Abilities:    #{result[:abilities]}"
puts "Difficulties: #{result[:difficulties]}"
puts "Converged:    #{result[:converged]} after #{result[:iterations]} iterations"
```

The third respondent answered every item correctly, so their ability has no
finite estimate and is returned as `nil` (see [Estimation Details](#estimation-details)).

Response data passed to model constructors must be either a `Matrix` or an
array of arrays. Each response value must be the integer `0`, the integer `1`,
or `nil` for missing data; floats such as `0.0`/`1.0`, strings, booleans, and
other values are rejected.

### Using 2PL and 3PL Models
```ruby
two_pl_model = IrtRuby::TwoParameterModel.new(data)
two_pl_result = two_pl_model.fit
puts two_pl_result[:abilities]
puts two_pl_result[:difficulties]
puts two_pl_result[:discriminations]

three_pl_model = IrtRuby::ThreeParameterModel.new(data)
three_pl_result = three_pl_model.fit
puts three_pl_result[:abilities]
puts three_pl_result[:difficulties]
puts three_pl_result[:discriminations]
puts three_pl_result[:guessings]
```

Three respondents are far too few for 2PL or 3PL: on this matrix `fit` returns
`converged: false`. Discrimination and guessing estimates need hundreds of
respondents.

## Handling Missing Data
Real-world data often has missing responses. Each model (Rasch, 2PL, 3PL) accepts a `missing_strategy:` option to handle nil entries:

- `:ignore` (default): Skip `nil` responses entirely in the log-likelihood and gradient calculations.
- `:treat_as_incorrect`: Interpret `nil` as `0`.
- `:treat_as_correct`: Interpret `nil` as `1`.

For example:
```ruby
data_with_missing = [
  [1, nil, 0],
  [nil, 1,  0],
  [0,  1,  1]
]

model = IrtRuby::RaschModel.new(
  data_with_missing,
  max_iter: 300,
  learning_rate: 0.01,
  missing_strategy: :treat_as_incorrect
)
result = model.fit

puts "Abilities:    #{result[:abilities]}"
puts "Difficulties: #{result[:difficulties]}"
```
This flexibility helps you handle datasets where missingness might signify a skipped item or an unanswered question.

## Advanced Usage

### Adaptive Learning Rate & Convergence
By default, each model uses a gradient ascent with:

- An adaptive learning rate: if log-likelihood decreases, the step is reverted and the rate is multiplied by `decay_factor`; after each accepted step the rate grows by 10%.
- A stopping rule on the change in log-likelihood and the average parameter update.
- A stationarity check that decides whether the stopping point is reported as converged.

You can customize:

- `max_iter`: The maximum number of iterations.
- `tolerance` and `param_tolerance`: Stopping thresholds for log-likelihood change and parameter updates.
- `gradient_tolerance` (default `1e-3`): `fit` reports `converged: true` only if, for every parameter, the gradient averaged over the responses it depends on is below this value.
- `learning_rate`: Initial learning rate.
- `decay_factor`: Factor by which the learning rate is reduced on a failed step.

`fit` returns `converged: false` when `max_iter` runs out or when the stopping rule fires away from a stationary point, for example because the learning rate became too small to move. Check this flag before using the estimates; a larger `learning_rate` or `max_iter` usually helps.

Example:
```ruby
IrtRuby::TwoParameterModel.new(
  data,
  max_iter: 500,
  tolerance: 1e-7,
  param_tolerance: 1e-7,
  learning_rate: 0.05,
  decay_factor: 0.5
)
```

### Reproducible Initialization
Each model initializes parameters randomly. By default, constructors use Ruby's global random number generator, preserving the historical behavior and honoring any external `srand` calls. For reproducible model initialization without resetting or consuming global RNG state, pass `seed:`:

```ruby
model_a = IrtRuby::ThreeParameterModel.new(data, seed: 1234)
model_b = IrtRuby::ThreeParameterModel.new(data, seed: 1234)

# Same data, options, and seed produce identical fitted results.
model_a.fit == model_b.fit #=> true
```

The `seed:` keyword is available for `RaschModel`, `TwoParameterModel`, and `ThreeParameterModel`.

### Parameter Clamping
For 2PL and 3PL:

- **Discriminations** (`a`) are clamped between `0.01` and `5.0` during optimization.
- **Guessings** (`c`, 3PL only) are clamped to `[0.0, 0.35]`.

These bounds are model restrictions: a 3PL item with a true lower asymptote above `0.35` cannot be represented. The bounds apply to the internal optimization scale; returned discriminations are multiplied by the internal ability SD (see below), so they can lie outside `[0.01, 5.0]`.

## Estimation Details

All models estimate person and item parameters jointly by maximizing the likelihood (joint maximum likelihood, JMLE).

- **Which parameters are estimated.** Think of the responses as a directed graph: a correct answer links the item to the respondent, an incorrect answer links the respondent to the item. Finite estimates on a common scale exist only within a strongly connected part of this graph, so IrtRuby estimates the largest such part and returns `nil` for every other respondent and item. This excludes respondents who answered every observed item correctly or every item incorrectly, items that everyone answered correctly or incorrectly, rows and columns with no observed responses, groups that are perfectly separated from the rest (for example, a group of respondents who answered every item of another group correctly), and groups that share no responses with the rest. Missing-data strategies are applied first, so `:treat_as_correct` and `:treat_as_incorrect` can create such patterns. For the Rasch model, and for 2PL with its bounded discriminations, this condition guarantees that finite estimates exist (the optimizer may still need more iterations to reach them). For 3PL it is necessary but not sufficient: fits can drift toward boundary solutions in which an item's difficulty keeps growing while its guessing parameter carries the item. Treat very large difficulties, or results with `converged: false`, as unreliable.
- **3PL and all-incorrect respondents.** Under 3PL, an excluded respondent who answered every estimated item incorrectly still informs the guessing parameters: as their ability tends to minus infinity each response has probability `1 - c`, and that limiting term stays in the likelihood.
- **Scale identification.** Results are reported on a fixed scale: Rasch abilities are centered to mean 0; 2PL and 3PL abilities are standardized to mean 0 and standard deviation 1, with difficulties and discriminations transformed so that response probabilities are unchanged. Only estimated respondents enter these statistics. The model keeps its internal parameters, so calling `fit` again continues from where it stopped; convergence is checked on the reported scale.
- **Known limitations.** JMLE item estimates are biased when tests are short, and the bias does not vanish as the number of respondents grows. 2PL and 3PL JMLE is also slow to converge with plain gradient ascent. For high-stakes calibration, compare against marginal maximum likelihood software such as R's `mirt`.

## Performance Benchmarks

IRT Ruby includes comprehensive performance benchmarks to help you understand the computational characteristics of different models:

```bash
# Run all benchmarks (takes 8-15 minutes)
bundle exec rake benchmark:all

# Quick performance check (2-3 minutes)
bundle exec rake benchmark:quick

# Individual benchmark suites
bundle exec rake benchmark:performance
bundle exec rake benchmark:convergence
```

The benchmarks test:
- **Performance**: Execution speed across dataset sizes (50 to 100,000 data points)
- **Memory Usage**: Object allocation and memory efficiency
- **Scaling**: How computational complexity grows with data size
- **Convergence**: Optimization behavior under different conditions

See `benchmarks/README.md` for detailed information about interpreting results.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` for the test suite or `bundle exec rake` for the default local quality gate: the RSpec suite and RuboCop. Before tagging a release, run `bundle exec rake build` to verify the gemspec packages cleanly from the current file list; CI also installs the built gem and smoke-tests `require 'irt_ruby'`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SyntaxSpirits/irt_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IrtRuby project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).
