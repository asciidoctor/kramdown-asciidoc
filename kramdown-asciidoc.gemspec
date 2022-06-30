require File.absolute_path 'lib/kramdown-asciidoc/version', __dir__
require 'open3' unless defined? Open3

Gem::Specification.new do |s|
  s.name = 'kramdown-asciidoc'
  s.version = Kramdown::AsciiDoc::VERSION
  s.summary = 'A Markdown to AsciiDoc converter based on kramdown'
  s.description = 'A kramdown extension for converting Markdown documents to AsciiDoc.'

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
  # NOTE required ruby version is informational only; it's not enforced since it can't be overridden and can cause builds to break
  #s.required_ruby_version = '>= 2.3.0'

  files = begin
    (result = Open3.popen3('git ls-files -z') {|_, out| out.read }.split ?\0).empty? ? Dir['**/*'] : result
  rescue
    Dir['**/*']
  end
  s.files = files.grep %r/^(?:lib\/.+|Gemfile|(?:CHANGELOG|LICENSE|README)\.adoc|#{s.name}\.gemspec)$/
  #s.test_files = files.grep %r/^spec\/./
  s.executables = ['kramdoc']

  s.require_paths = ['lib']

  s.add_runtime_dependency 'kramdown', '~> 2.4.0'
  s.add_runtime_dependency 'rexml', '~> 3.2.0'
  s.add_runtime_dependency 'kramdown-parser-gfm', '~> 1.1.0'

  s.add_development_dependency 'rake', '~> 13.0.0'
  s.add_development_dependency 'rspec', '~> 3.11.0'
end
