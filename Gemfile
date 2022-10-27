# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :docs do
  gem 'asciidoctor', require: false
  gem 'yard', require: false
end

group :lint do
  gem 'rubocop', '~> 1.28.0', require: false
  gem 'rubocop-rake', '~> 0.6.0', require: false
  gem 'rubocop-rspec', '~> 2.10.0', require: false
end

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.21.0', require: false
end
