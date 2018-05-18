# -*- encoding: utf-8 -*-
require File.expand_path '../lib/kramdown-asciidoc/version', __FILE__

Gem::Specification.new do |s|
  s.name = 'kramdown-asciidoc'
  s.version = Kramdown::Asciidoc::VERSION
  s.authors = ['Dan Allen']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'https://github.com/opendevise/kramdown-asciidoc'
  s.summary = 'A Markdown to AsciiDoc converter using Kramdown'
  s.description = 'A Kramdown extension for converting Markdown content to AsciiDoc.'
  s.license = 'MIT'

  s.files = Dir['lib/*', 'lib/*/**']
  s.executables = ['kramdown-asciidoc']
  s.extra_rdoc_files = Dir['README.doc', 'LICENSE.adoc']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'kramdown', '~> 1.16.2'
  s.add_development_dependency 'rake', '~> 12.3.1'
  s.add_development_dependency 'rspec', '~> 3.7.0'
end
