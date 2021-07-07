# frozen_string_literal: true

class Kramdown::Parser::Html::ElementConverter
  # Overload the convert_br method to add the :html_tag option to indicate this element originates from an HTML tag.
  #
  # @param el [Kramdown::Element] The element that represents an HTML br tag.
  #
  # @return [void]
  def convert_br el
    el.options.replace location: el.options[:location], html_tag: true
    el.type = el.value.to_sym
    el.value = nil
    nil
  end
end
