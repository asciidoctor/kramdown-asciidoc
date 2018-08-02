module Kramdown; module AsciiDoc
  LF = ?\n

  def self.convert markdown, opts = {}
    markdown = markdown.rstrip
    markdown = markdown.slice 1, markdown.length while markdown.start_with? LF
    attributes = (opts[:attributes] ||= {})
    markdown = ::Kramdown::AsciiDoc.extract_front_matter markdown, attributes
    markdown = ::Kramdown::AsciiDoc.replace_toc markdown, attributes
    asciidoc = (::Kramdown::Document.new markdown, (::Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS.merge opts)).to_asciidoc
    asciidoc += LF unless asciidoc.empty?
    if (to = opts[:to])
      (to.respond_to? :write) ? (to.write asciidoc) : (::IO.write to, asciidoc)
      nil
    else
      asciidoc
    end
  end

  def self.convert_file markdown_file, opts = {}
    markdown = ::IO.read markdown_file, mode: 'r:UTF-8', newline: :universal
    (output_file = (::Pathname.new markdown_file).sub_ext '.adoc').dirname.mkpath
    convert markdown, (opts.merge to: output_file)
  end
end; end

Kramdoc = Kramdown::AsciiDoc
