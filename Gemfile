source 'https://rubygems.org'

gemspec

group :coverage do
  gem 'deep-cover', git: 'https://github.com/mojavelinux/deep-cover', branch: 'no-cli', require: false
  gem 'sass', require: false unless ENV['CI']
end
