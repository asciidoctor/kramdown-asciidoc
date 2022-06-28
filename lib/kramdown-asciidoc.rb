# frozen_string_literal: true

require 'kramdown'
require_relative 'kramdown-asciidoc/kramdown_ext/parser/base'
require_relative 'kramdown-asciidoc/kramdown_ext/parser/html'
require_relative 'kramdown-asciidoc/core_ext/regexp/is_match'
require_relative 'kramdown-asciidoc/core_ext/yaml'
require_relative 'kramdown-asciidoc/preprocessors'
require_relative 'kramdown-asciidoc/writer'
require_relative 'kramdown-asciidoc/converter'
require_relative 'kramdown-asciidoc/api'
# register AsciiDoc converter with kramdown
Kramdown::Converter::Asciidoc = Kramdown::AsciiDoc::Converter
# add Kramdoc alias
Kramdoc = Kramdown::AsciiDoc
autoload :Pathname, 'pathname'
