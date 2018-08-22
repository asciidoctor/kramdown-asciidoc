module Kramdown; module AsciiDoc
  CR = ?\r
  LF = ?\n
  UTF_8 = ::Encoding::UTF_8

  def self.convert markdown, opts = {}
    unless opts[:encode] == false || (markdown.encoding == UTF_8 && !(markdown.include? CR))
      markdown = markdown.encode UTF_8, universal_newline: true
    end
    markdown = markdown.rstrip
    markdown = markdown.slice 1, markdown.length while markdown.start_with? LF
    parser_opts = ::Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS.merge opts
    attributes = (parser_opts[:attributes] = (parser_opts[:attributes] || {}).dup)
    markdown = ::Kramdown::AsciiDoc.extract_front_matter markdown, attributes
    markdown = ::Kramdown::AsciiDoc.replace_toc markdown, attributes
    asciidoc = (kramdown_doc = ::Kramdown::Document.new markdown, parser_opts).to_asciidoc
    if (postprocess = opts[:postprocess])
      asciidoc = (postprocess.arity == 1 ? postprocess[asciidoc] : postprocess[asciidoc, kramdown_doc]) || asciidoc
    end
    asciidoc += LF unless asciidoc.empty?
    if (to = opts[:to])
      if ::Pathname === to || (!(to.respond_to? :write) && (to = ::Pathname.new to.to_s))
        to.dirname.mkpath
        to.write asciidoc, encoding: UTF_8
      else
        to.write asciidoc
      end
      nil
    else
      asciidoc
    end
  end

  def self.convert_file markdown_file, opts = {}
    markdown = ::IO.read markdown_file, mode: 'r:UTF-8', newline: :universal
    if (to = opts[:to])
      to = ::Pathname.new to.to_s unless ::Pathname === to || (to.respond_to? :write)
    else
      unless opts.key? :to
        to = (::Pathname.new markdown_file).sub_ext '.adoc'
        raise ::IOError, %(input and output cannot be the same file: #{markdown_file}) if to.to_s == markdown_file.to_s
      end
    end
    convert markdown, (opts.merge to: to, encode: false)
  end
end; end
