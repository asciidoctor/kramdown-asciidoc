class Kramdown::Parser::Base
  # Overload parse to force value of :auto_ids option to false; handled by converter instead
  def self.parse source, options
    (parser = new source, (options.merge auto_ids: false, auto_id_stripping: false)).parse
    [parser.root, parser.warnings]
  end
end
