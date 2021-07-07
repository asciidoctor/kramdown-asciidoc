# frozen_string_literal: true

require_relative 'spec_helper'
require 'yaml'

describe 'scenario' do
  let(:doc) { Kramdown::Document.new input, (Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS.merge extra_options) }

  Dir.chdir scenarios_dir do
    (Dir.glob '**/*.md').each do |input_filename|
      input_stem = input_filename.slice 0, input_filename.length - 3
      scenario_name = input_stem.gsub '/', '::'
      options_filename = %(#{input_stem}.opts)
      options = (File.exist? options_filename) ? (YAML.load_file options_filename) : {}
      input_filename = File.absolute_path input_filename
      output_filename = File.absolute_path %(#{input_stem}.adoc)
      context %(for #{scenario_name}) do
        let(:input) { File.read input_filename, mode: 'r:UTF-8', newline: :universal }
        let(:extra_options) { options }
        let(:expected) { (File.read output_filename, mode: 'r:UTF-8', newline: :universal).chomp }

        it 'converts Markdown to AsciiDoc' do
          (expect doc.to_asciidoc).to eql expected
        end
      end
    end
  end
end
