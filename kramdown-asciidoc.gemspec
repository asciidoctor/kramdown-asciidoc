require File.absolute_path 'lib/kramdown-asciidoc/version', __dir__
require 'open3' unless defined? Open3

Gem::Specification.new do |s|
  s.name = 'kramdown-asciidoc'
  s.version = Kramdown::AsciiDoc::VERSION
  s.summary = 'A Markdown to AsciiDoc converter based on Kramdown'
  s.description = 'A Kramdown extension for converting Markdown documents to AsciiDoc.'

  s.authors = ['Dan Allen']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'https://github.com/asciidoctor/kramdown-asciidoc'
  s.license = 'MIT'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/asciidoctor/kramdown-asciidoc/issues',
    'changelog_uri' => 'https://github.com/asciidoctor/kramdown-asciidoc/blob/master/CHANGELOG.adoc',
    'mailing_list_uri' => 'http://discuss.asciidoctor.org',
    'source_code_uri' => 'https://github.com/asciidoctor/kramdown-asciidoc'
  }
  #s.required_ruby_version = '>= 2.4.0'

  files = begin
    (result = Open3.popen3('git ls-files -z') {|_, out| out.read }.split ?\0).empty? ? Dir['**/*'] : result
  rescue
    Dir['**/*']
  end
  s.files = files.grep %r/^(?:lib\/.+|Gemfile|Rakefile|(?:CHANGELOG|CONTRIBUTING|LICENSE|README)\.adoc|#{s.name}\.gemspec)$/
  s.test_files = files.grep %r/^(?:spec\/.+)$/
  s.executables = ['kramdoc']

  s.require_paths = ['lib']

  #s.has_rdoc = true
  #s.rdoc_options = ['--charset=UTF-8']
  #s.extra_rdoc_files = ['CHANGELOG.adoc', 'LICENSE.adoc']

  s.add_runtime_dependency 'kramdown', '~> 1.17.0'
  s.add_development_dependency 'rake', '~> 12.3.1'
  s.add_development_dependency 'rspec', '~> 3.7.0'
  s.add_development_dependency 'simplecov', '~> 0.16.1'
end
