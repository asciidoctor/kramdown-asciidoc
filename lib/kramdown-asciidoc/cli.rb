# frozen_string_literal: true

require 'optparse'
require 'pathname'

module Kramdown
module AsciiDoc
  autoload :VERSION, (::File.join __dir__, 'version.rb')
  class Cli
    def parse args
      options = {
        attributes: {},
      }

      opt_parser = ::OptionParser.new do |opts|
        opts.program_name = 'kramdoc'
        opts.banner = <<~EOS
        Usage: #{opts.program_name} [OPTION]... FILE

        Converts Markdown to AsciiDoc.

        EOS

        opts.on '-o FILE', '--output=FILE', 'Set the output filename or stream' do |file|
          options[:output_file] = file
        end

        opts.on '--format=GFM|kramdown|markdown', %w(kramdown markdown GFM), 'Set the flavor of Markdown to parse (default: GFM)' do |format|
          options[:input] = format
        end

        opts.on '-a KEY[=VALUE]', '--attribute=KEY[=VALUE]', 'Set an attribute in the AsciiDoc document header (accepts: key, key!, or key=value)' do |attr|
          key, val = attr.split '=', 2
          val ||= ''
          options[:attributes][key] = val
        end

        opts.on '--diagram-languages=VALUES', 'Specify source languages to treat as diagrams (default: plantuml,mermaid)' do |names|
          options[:diagram_languages] = names.split ','
        end

        opts.on '--wrap=preserve|none|ventilate', [:none, :preserve, :ventilate], 'Set how lines are wrapped in the AsciiDoc document (default: preserve)' do |wrap|
          options[:wrap] = wrap
        end

        opts.on '--imagesdir=DIR', 'Set the imagesdir attribute in the AsciiDoc document header (also remove the value from the start of image paths)' do |dir|
          options[:imagesdir] = dir
        end

        opts.on '--heading-offset=NUMBER', ::Integer, 'Shift the heading level by the specified number' do |offset|
          options[:heading_offset] = offset
        end

        opts.on '--[no-]html-to-native', 'Set whether to passthrough HTML or convert it to AsciiDoc syntax where possible (default: true)' do |html_to_native|
          options[:html_to_native] = html_to_native
        end

        opts.on '--auto-ids', 'Set whether to auto-generate IDs for all section titles' do |auto_ids|
          options[:auto_ids] = auto_ids
        end

        opts.on '--auto-id-prefix=STRING', 'Set the prefix to use for auto-generated section title IDs' do |string|
          options[:auto_id_prefix] = string
        end

        opts.on '--auto-id-separator=CHAR', 'Set the separator char to use for auto-generated section title IDs' do |char|
          options[:auto_id_separator] = char
        end

        opts.on '--lazy-ids', 'Set whether to drop IDs that match value of auto-generated ID' do |lazy_ids|
          options[:lazy_ids] = lazy_ids
        end

        opts.on '--[no-]auto-links', 'Set whether to automatically convert bare URLs into links (default: true)' do |auto_links|
          options[:auto_links] = auto_links
        end

        opts.on '-h', '--help', 'Display this help text and exit' do
          $stdout.write opts.help
          return 0
        end

        opts.on '-v', '--version', %(Display version information and exit) do
          $stdout.write %(#{opts.program_name} #{::Kramdown::AsciiDoc::VERSION}\n)
          return 0
        end
      end

      args = opt_parser.parse args

      if args.empty?
        opt_parser.warn 'Please specify a Markdown file to convert.'
        $stdout.write opt_parser.help
        1
      elsif args.size == 1
        options[:input_file] = args[0]
        [0, options]
      else
        opt_parser.warn %(extra arguments detected (unparsed arguments: #{(args.drop 1).join ' '}))
        $stdout.write opt_parser.help
        [1, options]
      end
    rescue ::OptionParser::InvalidOption
      $stderr.write %(#{opt_parser.program_name}: #{$!.message}\n)
      $stdout.write opt_parser.help
      1
    end

    def self.run args = ARGV
      code, options = new.parse (Array args)
      return code unless code == 0 && options
      pipe_in = (input_file = options.delete :input_file) == '-'
      pipe_out = (output_file = options.delete :output_file) == '-'
      if pipe_in
        options[:to] = pipe_out || !output_file ? $stdout : output_file
        ::Kramdoc.convert $stdin, options
      elsif output_file && !pipe_out && (::File.expand_path input_file) == (::File.expand_path output_file)
        $stderr.write %(kramdoc: input and output cannot be the same file: #{input_file}\n)
        return 1
      else
        options[:to] = pipe_out ? $stdout : output_file if output_file
        ::Kramdoc.convert_file input_file, options
      end
      0
    rescue ::IOError
      $stderr.write %(kramdoc: #{$!.message}\n)
      1
    end
  end
end
end
