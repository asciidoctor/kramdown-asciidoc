# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

without = (Bundler.settings['WITHOUT'] || '').split ':'

group :docs do
  gem 'asciidoctor', require: false
  gem 'yard', require: false
end unless without.include? 'docs'

group :lint do
  gem 'rubocop', '~> 1.18.0', require: false
  gem 'rubocop-rake', '~> 0.6.0', require: false
  gem 'rubocop-rspec', '~> 2.4.0', require: false
end unless without.include? 'lint'

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.21.0', require: false
end unless without.include? 'coverage'
