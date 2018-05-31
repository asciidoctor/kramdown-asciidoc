if ENV['COVERAGE'] == 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
  SimpleCov.start do
    add_filter %w(/.bundle/ /spec/)
    coverage_dir 'build/coverage-report'
  end
end

require 'kramdown-asciidoc'
