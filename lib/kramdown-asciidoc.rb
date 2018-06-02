require 'kramdown'
require_relative 'kramdown-asciidoc/converter'
autoload :YAML, 'yaml'

class Kramdown::Parser::Html::ElementConverter
  def convert_br el
    el.options.replace location: el.options[:location], html_tag: true
    el.type = el.value.to_sym
    el.value = nil
    nil
  end
end
