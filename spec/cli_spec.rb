require_relative 'spec_helper'
require 'kramdown-asciidoc/cli'
require 'stringio'

describe Kramdown::AsciiDoc::Cli do
  subject { Kramdown::AsciiDoc::Cli }

  before :each do
    @old_stdout, $stdout = $stdout, StringIO.new
    @old_stderr, $stderr = $stderr, StringIO.new
  end

  after :each do
    $stdout, $stderr = @old_stdout, @old_stderr
  end

  context 'option flags' do
    it 'returns non-zero exit status and displays usage when no arguments are given' do
      expected = 'kramdoc: Please specify a Markdown file to convert.'
      (expect subject.run []).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string.chomp).to start_with 'Usage: kramdoc'
    end

    it 'returns non-zero exit status and displays usage when more than one argument is given' do
      expected = 'kramdoc: extra arguments detected (unparsed arguments: bar.md)'
      (expect subject.run %w(foo.md bar.md)).to eql 1
      (expect $stderr.string.chomp).to eql expected
      (expect $stdout.string.chomp).to start_with 'Usage: kramdoc'
    end

    it 'returns non-zero exit status when invalid argument is given' do
      (expect subject.run %w(--invalid-option)).to eql 1
      (expect $stderr.string.chomp).to eql 'kramdoc: invalid option: --invalid-option'
      (expect $stdout.string.chomp).to start_with 'Usage: kramdoc'
    end

    it 'displays version when -v flag is used' do
      (expect subject.run %w(-v)).to eql 0
      (expect $stdout.string.chomp).to eql %(kramdoc #{Kramdown::AsciiDoc::VERSION})
    end

    it 'displays help when -h flag is used' do
      (expect subject.run %w(-h)).to eql 0
      (expect $stdout.string.chomp).to start_with 'Usage: kramdoc'
    end

    it 'computes output file from input file' do
      the_source_file = output_file 'implicit-output.md'
      the_output_file = output_file 'implicit-output.adoc'
      IO.write the_source_file, 'This is just a test.'
      (expect subject.run %W(#{the_source_file})).to eql 0
      (expect (IO.read the_output_file).chomp).to eql 'This is just a test.'
    end

    it 'writes output to file specified by the -o option' do
      the_source_file = output_file 'explicit-output.md'
      the_output_file = output_file 'my-explicit-output.adoc'
      IO.write the_source_file, 'This is only a test.'
      (expect subject.run %W(-o #{the_output_file} #{the_source_file})).to eql 0
      (expect (IO.read the_output_file).chomp).to eql 'This is only a test.'
    end

    it 'ensures directory of explicit output file exists before writing' do
      the_source_file = output_file 'ensure-output-dir.md'
      the_output_file = output_file 'path/to/output/file.adoc'
      IO.write the_source_file, 'Everything is going to be fine.'
      (expect subject.run %W(-o #{the_output_file} #{the_source_file})).to eql 0
      (expect (IO.read the_output_file).chomp).to eql 'Everything is going to be fine.'
    end

    it 'writes output to stdout when -o option equals -' do
      the_source_file = scenario_file 'p/single-line.md'
      (expect subject.run %W(-o - #{the_source_file})).to eql 0
      (expect $stdout.string.chomp).to eql 'A paragraph that consists of a single line.'
    end

    it 'reads input from stdin when argument is -' do
      old_stdin, $stdin = $stdin, StringIO.new
      begin
        $stdin.puts '- list item'
        $stdin.rewind
        (expect subject.run %W(-o - -)).to eql 0
        (expect $stdout.string.chomp).to eql '* list item'
      ensure
        $stdin = old_stdin
      end
    end

    it 'removes leading blank lines and trailing whitespace from source' do
      the_source_file = output_file 'leading-trailing-space.md'
      IO.write the_source_file, %(\n\n\n\n# Heading\n\ncontent.   \n\n)
      (expect subject.run %W(-o - #{the_source_file})).to eql 0
      (expect $stdout.string.chomp).to eql %(= Heading\n\ncontent.)
    end

    it 'reads Markdown source using specified format' do
      the_source_file = output_file 'format-markdown.md'
      IO.write the_source_file, '#Heading'
      (expect subject.run %W(-o - --format=markdown #{the_source_file})).to eql 0
      (expect $stdout.string.chomp).to eql '= Heading'
    end

    it 'wraps output as specified by the --wrap option' do
      the_source_file = scenario_file 'wrap/ventilate.md'
      expected = IO.read scenario_file 'wrap/ventilate.adoc'
      (expect subject.run %W(-o - --wrap=ventilate #{the_source_file})).to eql 0
      (expect $stdout.string).to eql expected
    end

    it 'shifts headings by offset when --heading-offset is used' do
      the_source_file = scenario_file 'heading/offset.md'
      expected = IO.read scenario_file 'heading/offset.adoc'
      (expect subject.run %W(-o - --heading-offset=-1 #{the_source_file})).to eql 0
      (expect $stdout.string).to eql expected
    end

    it 'automatically generates IDs for section titles when --auto-ids is used' do
      the_source_file = scenario_file 'heading/auto-ids.md'
      expected = IO.read scenario_file 'heading/auto-ids.adoc'
      (expect subject.run %W(-o - --auto-ids #{the_source_file})).to eql 0
      (expect $stdout.string).to eql expected
    end

    it 'adds specified attributes to document header' do
      the_source_file = scenario_file 'root/header-and-body.md'
      (expect subject.run %W(-o - -a idprefix -a idseparator=- #{the_source_file})).to eql 0
      expected = <<~EOS
      = Document Title
      :idprefix:
      :idseparator: -

      Body content.
      EOS
      (expect $stdout.string).to eql expected
    end

    it 'passes through HTML when --no-html-to-native flag is used' do
      the_source_file = scenario_file 'html_element/native.md'
      (expect subject.run %W(-o - --no-html-to-native #{the_source_file})).to eql 0
      expected = <<~EOS
      +++<p>++++++<strong>+++strong emphasis (aka bold)+++</strong>+++ +++<em>+++emphasis (aka italic)+++</em>+++ +++<code>+++monospace+++</code>++++++</p>+++
      EOS
      (expect $stdout.string).to eql expected
    end

    it 'reads arguments from ARGV by default' do
      old_ARGV = ARGV.dup
      ARGV.replace %w(-v)
      begin
        (expect subject.run).to eql 0
        (expect $stdout.string.chomp).to eql %(kramdoc #{Kramdown::AsciiDoc::VERSION})
      ensure
        ARGV.replace old_ARGV
      end
    end
  end
end
