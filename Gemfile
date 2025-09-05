# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.21.0', require: false
end

group :docs do
  gem 'asciidoctor', require: false
  gem 'yard', require: false
end

group :lint do
  gem 'json', '~> 2.6.0', require: false
  gem 'rubocop', '~> 1.36.0', require: false
  gem 'rubocop-rake', '~> 0.6.0', require: false
  gem 'rubocop-rspec', '~> 2.13.0', require: false
end unless (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.6.0')
