require 'optparse'
require 'pathname'

module Kramdown; module AsciiDoc
  class Cli
    def parse args
      options = {
        attributes: {},
        input: 'GFM',
        html_to_native: true,
      }

      opt_parser = ::OptionParser.new do |opts|
        opts.program_name = 'kramdoc'
        opts.banner = <<~EOS
        Usage: #{opts.program_name} [OPTION]... FILE...

        Converts Markdown to AsciiDoc.

        EOS

        opts.on '-o FILE', '--output=FILE', 'Set the output filename or stream' do |file|
          options[:output] = file
        end

        opts.on '--format=GFM|kramdown|markdown', %w(kramdown markdown GFM), 'Set the flavor of Markdown to parse (default: GFM)' do |format|
          options[:input] = format
        end

        opts.on '-a KEY[=VALUE]', '--attribute=KEY[=VALUE]', 'Set an attribute in the document header (accepts: key, key!, or key=value' do |attr|
          key, val = attr.split '=', 2
          val = '' unless val
          options[:attributes][key] = val
        end

        opts.on '--heading-offset=NUMBER', 'Shift the heading level by the specified number', ::Integer do |offset|
          options[:heading_offset] = offset
        end

        opts.on '--[no-]html-to-native', 'Set whether to passthrough HTML or convert it to AsciiDoc syntax where possible (default: true)' do |html_to_native|
          options[:html_to_native] = html_to_native
        end

        opts.on '--auto-ids', 'Set whether to auto-generate IDs for section titles' do |auto_ids|
          options[:auto_ids] = auto_ids
        end

        opts.on '-h', '--help', 'Display this help text and exit' do
          $stdout.puts opts.help
          return 0
        end

        opts.on '-v', '--version', %(Display version information and exit) do
          $stdout.puts %(#{opts.program_name} #{VERSION})
          return 0
        end
      end

      args = opt_parser.parse args

      if args.empty?
        opt_parser.warn 'Please specify a Markdown file to convert.'
        $stderr.puts opt_parser.help
        return 1
      end

      if args.size == 1
        options[:source] = args[0]
        [0, options]
      else
        opt_parser.warn %(extra arguments detected (unparsed arguments: #{(args.drop 1).join ' '}))
        $stderr.puts opt_parser.help
        [1, options]
      end
    end

    def self.run args = ARGV
      code, options = new.parse args
      return code unless code == 0 && options
      if (source_file = options.delete :source) == '-'
        markdown = $stdin.read.rstrip
      else
        markdown = (::IO.read source_file, mode: 'r:UTF-8', newline: :universal).rstrip
      end
      if (output_file = options.delete :output)
        (Pathname output_file).dirname.mkpath
      else
        output_file = ((Pathname source_file).sub_ext '.adoc').to_s
      end
      markdown = markdown.slice 1, markdown.length while markdown.start_with? ?\n
      attributes = options[:attributes]
      markdown = ::Kramdown::AsciiDoc.extract_front_matter markdown, attributes
      markdown = ::Kramdown::AsciiDoc.replace_toc markdown, attributes
      doc = ::Kramdown::Document.new markdown, (::Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS.merge options)
      if output_file == '-'
        $stdout.puts doc.to_asciidoc
      else
        ::IO.write output_file, doc.to_asciidoc
      end
      0
    end
  end
end; end
