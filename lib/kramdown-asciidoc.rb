require 'kramdown'
require_relative 'kramdown-asciidoc/converter'
autoload :YAML, 'yaml'

class Kramdown::Parser::Html::ElementConverter
  def convert_br el
    el.options.replace location: el.options[:location], html_tag: true
    el.type = el.value.to_sym
    # REMOVE change value assignment to nil once Kramdown > 1.16.2 is released
    el.value = ''
    nil
  end
end
