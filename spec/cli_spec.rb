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

  context 'flags' do
    it 'displays version when -v flag is used' do
      (expect Kramdown::AsciiDoc::Cli.run %w(-v)).to eql 0
      (expect $stdout.string.chomp).to eql %(kramdoc #{Kramdown::AsciiDoc::VERSION})
    end

    it 'displays help when -h flag is used' do
      (expect Kramdown::AsciiDoc::Cli.run %w(-h)).to eql 0
      (expect $stdout.string.chomp).to include 'Usage: kramdoc'
    end

    it 'writes output to stdout when -o flag equals -' do
      source_file = File.absolute_path 'scenarios/p/single-line.md', __dir__
      (expect Kramdown::AsciiDoc::Cli.run %W(-o - #{source_file})).to eql 0
      (expect $stdout.string.chomp).to include 'A paragraph that consists of a single line.'
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
      source_file = File.absolute_path 'scenarios/heading/offset.md', __dir__
      (expect Kramdown::AsciiDoc::Cli.run %W(-o - --heading-offset=-1 #{source_file})).to eql 0
      (expect $stdout.string.chomp).to include '= Document Title'
    end
  end
end
