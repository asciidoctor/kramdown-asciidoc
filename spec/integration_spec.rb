require_relative 'spec_helper'
require 'yaml'

describe 'integration scenario' do
  FIXTURES_DIR = File.absolute_path 'fixtures', __dir__

  let(:doc) { Kramdown::Document.new input, (Kramdown::Converter::AsciiDoc::DEFAULT_PARSER_OPTS.merge extra_options) }

  (Dir.glob ([FIXTURES_DIR, '**', '*.md'].join '/')).each do |input_file|
    relative_path = input_file.slice FIXTURES_DIR.length + 1, input_file.length
    scenario_name = (relative_path.slice 0, relative_path.length - 3).gsub '/', '::'
    input_basename = File.basename input_file, '.md'
    options_file = [(File.dirname input_file), %(#{input_basename}.opts)].join '/'
    options = (File.exist? options_file) ? (YAML.load_file options_file) : {}
    output_file = [(File.dirname input_file), %(#{input_basename}.adoc)].join '/'
    context %(for #{scenario_name}) do
      let(:input) { ::IO.read input_file }
      let(:extra_options) { options }
      let(:expected) { (::IO.read output_file).chomp }
      it 'converts Markdown to AsciiDoc' do
        (expect doc.to_asciidoc).to eql expected
      end
    end
  end
end
