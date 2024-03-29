# frozen_string_literal: true

module Kramdown
module AsciiDoc
  DEFAULT_PARSER_OPTS = {
    auto_ids: false,
    hard_wrap: false,
    html_to_native: true,
    input: 'GFM',
  }

  DEFAULT_PREPROCESSORS = [
    (Preprocessors.method :extract_front_matter),
    (Preprocessors.method :replace_toc),
    (Preprocessors.method :trim_before_leading_comment),
  ]

  # Converts a Markdown string to an AsciiDoc string and either returns the result or writes it to a file.
  #
  # @param markdown [String, IO] the Markdown source to convert to AsciiDoc.
  # @param opts [Hash] additional options to configure the behavior of the converter.
  # @option opts [Boolean] :auto_ids (false) controls whether converter automatically generates an explicit ID for any
  #   section title (aka heading) that doesn't already have an ID assigned to it.
  # @option opts [String] :auto_id_prefix (nil) the prefix to add to an auto-generated ID.
  # @option opts [String] :auto_id_separator ('-') the separator to use in auto-generated IDs.
  # @option opts [Boolean] :lazy_ids (false) controls whether to drop the ID if it matches the auto-generated ID value.
  # @option opts [Symbol] :wrap (:preserve) the line wrapping behavior to apply (:preserve, :ventilate, or :none).
  # @option opts [Integer] :heading_offset (0) the heading offset to apply to heading levels.
  # @option opts [Boolean] :auto_links (true) whether to allow raw URLs to be recognized as links.
  # @option opts [Hash] :attributes ({}) additional AsciiDoc attributes to add to header of output document; reserved
  #   attributes, like stem, may be overridden; some attributes may impact conversion, such as idprefix and idseparator
  # @option opts [String] :imagesdir (nil) the prefix to remove from image references found in the Markdown document;
  #   if not specified, the value of the imagesdir attribute is used
  # @option opts [Symbol] :encode (true) whether to reencode the source to UTF-8.
  # @option opts [Array<Proc>] :preprocessors ([]) a list of preprocessors functions to execute on the cleaned Markdown source.
  # @option opts [Array<Proc>] :postprocessors ([]) a list of functions through which to run the output document.
  # @option opts [Proc] :postprocess (nil) a function through which to run the output document (if :postprocessors is falsy).
  # @option opts [String, Pathname] :to (nil) the path to which to write the output document.
  #
  # @return [String, nil] the converted AsciiDoc or nil if the :to option is specified.
  def self.convert markdown, opts = {}
    if markdown.respond_to? :read
      markdown = markdown.read
      encode = true
    else
      encode = opts[:encode]
    end
    unless encode == false || (markdown.encoding == UTF_8 && !(markdown.include? CR))
      markdown = markdown.encode UTF_8, universal_newline: true
    end
    markdown = markdown.rstrip
    markdown = markdown.slice 1, markdown.length while markdown.start_with? LF
    parser_opts = DEFAULT_PARSER_OPTS.merge opts
    attributes = (parser_opts[:attributes] = (parser_opts[:attributes] || {}).dup)
    ((opts.fetch :preprocessors, DEFAULT_PREPROCESSORS) || []).each do |preprocessor|
      markdown = preprocessor[markdown, attributes]
    end
    asciidoc = (kramdown_doc = ::Kramdown::Document.new markdown, parser_opts).to_asciidoc
    (opts[:postprocessors] || Array(opts[:postprocess])).each do |postprocessor|
      asciidoc = (postprocessor.arity == 1 ? postprocessor[asciidoc] : postprocessor[asciidoc, kramdown_doc]) || asciidoc
    end
    asciidoc += LF unless asciidoc.empty?
    if (to = opts[:to])
      if ::Pathname === to || (!(to.respond_to? :write) && (to = ::Pathname.new to.to_s))
        to.dirname.mkpath
        to.write asciidoc, encoding: UTF_8, newline: :universal
      else
        to.write asciidoc
      end
      nil
    else
      asciidoc
    end
  end

  # Converts a Markdown file to AsciiDoc and writes the result to a file or the specified destination.
  #
  # @param markdown_file [String, File] the Markdown file or file path to convert to AsciiDoc.
  # @param opts [Hash] additional options to configure the behavior of the converter.
  # @option opts [Boolean] :auto_ids (false) controls whether converter automatically generates an explicit ID for any
  #   section title (aka heading) that doesn't already have an ID assigned to it.
  # @option opts [String] :auto_id_prefix (nil) the prefix to add to an auto-generated ID.
  # @option opts [String] :auto_id_separator ('-') the separator to use in auto-generated IDs.
  # @option opts [Boolean] :lazy_ids (false) controls whether to drop the ID if it matches the auto-generated ID value.
  # @option opts [Symbol] :wrap (:preserve) the line wrapping behavior to apply (:preserve, :ventilate, or :none).
  # @option opts [Integer] :heading_offset (0) the heading offset to apply to heading levels.
  # @option opts [Boolean] :auto_links (true) whether to allow raw URLs to be recognized as links.
  # @option opts [Hash] :attributes ({}) additional AsciiDoc attributes to add to header of output document; reserved
  #   attributes, like stem, may be overridden; some attributes may impact conversion, such as idprefix and idseparator
  # @option opts [String] :imagesdir (nil) the prefix to remove from image references found in the Markdown document;
  #   if not specified, the value of the imagesdir attribute is used
  # @option opts [Array<Proc>] :preprocessors ([]) a list of preprocessors functions to execute on the cleaned Markdown source.
  # @option opts [Array<Proc>] :postprocessors ([]) a list of functions through which to run the output document.
  # @option opts [Proc] :postprocess (nil) a function through which to run the output document (if :postprocessors is falsy).
  # @option opts [String, Pathname] :to (nil) the path to which to write the output document.
  #
  # @return [String, nil] the converted document if the :to option is specified and is falsy, otherwise nil.
  def self.convert_file markdown_file, opts = {}
    if ::File === markdown_file
      markdown = markdown_file.read
      markdown_file = markdown_file.path
      encode = true
    else
      markdown = ::File.read markdown_file, mode: 'r:UTF-8', newline: :universal
      encode = false
    end
    if (to = opts[:to])
      to = ::Pathname.new to.to_s unless ::Pathname === to || (to.respond_to? :write)
    elsif !(opts.key? :to)
      to = (::Pathname.new markdown_file).sub_ext '.adoc'
      raise ::IOError, %(input and output cannot be the same file: #{markdown_file}) if to.to_s == markdown_file.to_s
    end
    convert markdown, (opts.merge to: to, encode: encode)
  end

  CR = ?\r
  LF = ?\n
  TAB = ?\t
  UTF_8 = ::Encoding::UTF_8

  private_constant :CR, :LF, :TAB, :UTF_8
end
end
