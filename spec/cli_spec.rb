require_relative 'spec_helper'
require 'kramdown-asciidoc/cli'
require 'stringio'

describe Kramdown::AsciiDoc::Cli do
  before :each do
    @old_stdout, $stdout = $stdout, StringIO.new
  end

  after :each do
    $stdout = @old_stdout
  end

  context 'option flags' do
    it 'displays version when -v flag is used' do
      (expect Kramdown::AsciiDoc::Cli.run %w(-v)).to eql 0
      (expect $stdout.string.chomp).to eql %(kramdoc #{Kramdown::AsciiDoc::VERSION})
    end

    it 'displays help when -h flag is used' do
      (expect Kramdown::AsciiDoc::Cli.run %w(-h)).to eql 0
      (expect $stdout.string.chomp).to start_with 'Usage: kramdoc'
    end

    it 'computes output file from input file' do
      the_source_file = output_file 'implicit-output.md'
      the_output_file = output_file 'implicit-output.adoc'
      IO.write the_source_file, 'This is just a test.'
      (expect Kramdown::AsciiDoc::Cli.run %W(#{the_source_file})).to eql 0
      (expect (IO.read the_output_file).chomp).to eql 'This is just a test.'
    end

    it 'writes output to file specified by the -o option' do
      the_source_file = output_file 'explicit-output.md'
      the_output_file = output_file 'my-explicit-output.adoc'
      IO.write the_source_file, 'This is only a test.'
      (expect Kramdown::AsciiDoc::Cli.run %W(-o #{the_output_file} #{the_source_file})).to eql 0
      (expect (IO.read the_output_file).chomp).to eql 'This is only a test.'
    end

    it 'writes output to stdout when -o option equals -' do
      the_source_file = scenario_file 'p/single-line.md'
      (expect Kramdown::AsciiDoc::Cli.run %W(-o - #{the_source_file})).to eql 0
      (expect $stdout.string.chomp).to eql 'A paragraph that consists of a single line.'
    end

    it 'reads input from stdin when argument is -' do
      old_stdin, $stdin = $stdin, StringIO.new
      begin
        $stdin.puts '- list item'
        $stdin.rewind
        (expect Kramdown::AsciiDoc::Cli.run %W(-o - -)).to eql 0
        (expect $stdout.string.chomp).to eql '* list item'
      ensure
        $stdin = old_stdin
      end
    end

    it 'shifts headings by offset when --heading-offset is used' do
      the_source_file = scenario_file 'heading/offset.md'
      (expect Kramdown::AsciiDoc::Cli.run %W(-o - --heading-offset=-1 #{the_source_file})).to eql 0
      (expect $stdout.string.chomp).to include '= Document Title'
    end

    it 'adds specified attributes to document header' do
      the_source_file = scenario_file 'root/header-and-body.md'
      (expect Kramdown::AsciiDoc::Cli.run %W(-o - -a idprefix -a idseparator=- #{the_source_file})).to eql 0
      expected = <<~EOS
      = Document Title
      :idprefix:
      :idseparator: -

      Body content.
      EOS
      (expect $stdout.string).to eql expected
    end
  end
end
