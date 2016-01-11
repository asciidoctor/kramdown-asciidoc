# -*- encoding: utf-8 -*-
require File.expand_path '../lib/kramdown-asciidoc/version', __FILE__

Gem::Specification.new do |s|
  s.name = 'kramdown-asciidoc'
  s.version = Kramdown::Asciidoc::VERSION
  s.authors = ['Dan Allen']
  s.email = ['dan.j.allen@gmail.com']
  s.homepage = 'https://github.com/opendevise/kramdown-asciidoc'
  s.summary = 'A Markdown to AsciiDoc converter using Kramdown'
  s.description = 'An extension for Kramdown for converting Markdown content to AsciiDoc.'
  s.license = 'MIT'

  s.files = Dir['lib/*', 'lib/*/**']
  s.executables = ['kramdown-asciidoc']
  s.extra_rdoc_files = Dir['README.doc', 'LICENSE.adoc']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'kramdown', '~> 1.9.0'
  s.add_development_dependency 'rake', '~> 10.4.2'
  s.add_development_dependency 'rspec', '~> 3.4.0'
end
