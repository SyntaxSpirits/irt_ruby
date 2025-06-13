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
```
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

## Handling Missing Data
Real-world data often has missing responses. Each model (Rasch, 2PL, 3PL) accepts a `missing_strategy: option` to handle nil entries:

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

- An adaptive learning rate (if log-likelihood decreases, it reverts the step and reduces the rate).
- Multiple convergence checks (change in log-likelihood and average parameter updates).

You can customize:

- `max_iter`: The maximum number of iterations.
- `tolerance` and `param_tolerance`: Convergence thresholds for log-likelihood change and parameter updates.
- `learning_rate`: Initial learning rate.
- `decay_factor`: Factor by which the learning rate is reduced on a failed step.

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
### Parameter Clamping
For 2PL and 3PL:

- **Discriminations** (`a`) are clamped between `0.01` and `5.0`.
- **Guessings** (`c`, 3PL only) are clamped to `[0.0, 0.35]`.

This prevents extreme or invalid parameter estimates.

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

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SyntaxSpirits/irt_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IrtRuby project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).
