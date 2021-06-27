source 'https://rubygems.org'

gemspec

group :docs do
  gem 'yard', require: false
  gem 'asciidoctor', require: false
end

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.21.0', require: false if (Gem::Version.new RUBY_VERSION) >= (Gem::Version.new '2.5.0')
end
