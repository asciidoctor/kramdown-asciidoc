require 'kramdown'
require_relative 'kramdown-asciidoc/converter'
autoload :YAML, 'yaml'

# REMOVE once Kramdown > 1.16.2 is released
class Kramdown::Parser::Html::ElementConverter
  def convert_br el
    el.options.clear
    el.type = el.value.to_sym
    el.value = ''
    nil
  end
end
