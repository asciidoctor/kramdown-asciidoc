module Kramdown; module AsciiDoc
  CR = ?\r
  LF = ?\n
  UTF_8 = ::Encoding::UTF_8

  def self.convert markdown, opts = {}
    unless (opts.delete :encode) == false || (markdown.encoding == UTF_8 && !(markdown.include? CR))
      markdown = markdown.encode UTF_8, universal_newline: true
    end
    markdown = markdown.rstrip
    markdown = markdown.slice 1, markdown.length while markdown.start_with? LF
    # QUESTION should we .dup?
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
    if opts.key? :to
      if (output_file = opts.delete :to)
        if ::Pathname === output_file
          output_file.dirname.mkpath
        elsif !(output_file.respond_to? :write)
          (output_file = ::Pathname.new output_file.to_s).dirname.mkpath
        end
      end
    else
      output_file = (::Pathname.new markdown_file).sub_ext '.adoc'
    end
    convert markdown, (opts.merge to: output_file, encode: false)
  end
end; end

Kramdoc = Kramdown::AsciiDoc
