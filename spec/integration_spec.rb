require_relative 'spec_helper'
require 'yaml'

describe 'integration scenario' do
  FIXTURES_DIR = File.absolute_path 'fixtures', __dir__

  let(:doc) { Kramdown::Document.new input, (Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS.merge extra_options) }

  Dir.chdir FIXTURES_DIR do
    (Dir.glob '**/*.md').each do |input_filename|
      input_stem = input_filename.slice 0, input_filename.length - 3
      scenario_name = input_stem.gsub '/', '::'
      options_filename = %(#{input_stem}.opts)
      options = (File.exist? options_filename) ? (YAML.load_file options_filename) : {}
      input_filename = File.absolute_path input_filename
      output_filename = File.absolute_path %(#{input_stem}.adoc)
      context %(for #{scenario_name}) do
        let(:input) { IO.read input_filename, mode: 'r:UTF-8', newline: :universal }
        let(:extra_options) { options }
        let(:expected) { IO.read output_filename, mode: 'r:UTF-8', newline: :universal }
        it 'converts Markdown to AsciiDoc' do
          (expect doc.to_asciidoc).to eql expected
        end
      end
    end
  end
end
