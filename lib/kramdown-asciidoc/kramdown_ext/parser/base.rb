class Kramdown::Parser::Base
  # Overload the parse method to force value of the :auto_ids option to false.
  #
  # The :auto_ids logic is handled instead by the Kramdown::AsciiDoc::Converter class
  #
  # @param source [String] the Markdown source string to parse.
  # @param options [Hash] additional options to configure parsing.
  #
  # @return [Array<Kramdown::Element, Array>] a tuple of the document root element and a list of warning objects.
  def self.parse source, options
    (parser = new source, (options.merge auto_ids: false, auto_id_stripping: false)).parse
    [parser.root, parser.warnings]
  end
end
