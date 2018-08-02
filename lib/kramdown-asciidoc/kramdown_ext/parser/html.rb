class Kramdown::Parser::Html::ElementConverter
  # Overload convert_br to add the :html_tag option to indicate this br element originates from an HTML tag
  def convert_br el
    el.options.replace location: el.options[:location], html_tag: true
    el.type = el.value.to_sym
    el.value = nil
    nil
  end
end
