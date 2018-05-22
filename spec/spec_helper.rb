if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start do
    add_filter %w(/.bundle/ /spec/)
    coverage_dir 'build/coverage-report'
  end
end

require 'kramdown-asciidoc'
