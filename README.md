
# IrtRuby

IrtRuby is a Ruby gem that provides implementations of the Rasch model and the Two-Parameter model for Item Response Theory (IRT). It allows you to estimate the abilities of individuals and the difficulties of items based on their responses to a set of items.

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

Here's an example of how to use the IrtRuby gem:

```ruby
require 'irt_ruby'
require 'matrix'

# Create a sample response matrix
data = Matrix[[1, 0, 1], [0, 1, 0], [1, 1, 1]]

# Initialize the Rasch model with the response data
model = IrtRuby::RaschModel.new(data)

# Fit the model to estimate abilities and difficulties
result = model.fit

# Output the estimated abilities and difficulties
puts "Abilities: #{result[:abilities]}"
puts "Difficulties: #{result[:difficulties]}"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SyntaxSpirits/irt_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the IrtRuby project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/SyntaxSpirits/irt_ruby/blob/main/CODE_OF_CONDUCT.md).
