require_relative 'spec_helper'

describe 'integration' do
  FIXTURES_DIR = File.absolute_path 'fixtures', __dir__

  let(:doc) { Kramdown::Document.new input, Kramdown::Converter::AsciiDoc::DEFAULT_PARSER_OPTS }

  context 'converts Markdown to AsciiDoc' do
    (Dir.glob ([FIXTURES_DIR, '**', '*.md'].join '/')).each do |input_file|
      relative_path = input_file.slice FIXTURES_DIR.length + 1, input_file.length
      scenario_name = (relative_path.slice 0, relative_path.length - 3).tr '/', ' '
      input_basename = File.basename input_file, '.md'
      output_file = [(File.dirname input_file), %(#{input_basename}.adoc)].join '/'
      let(:input) { ::IO.read input_file }
      let(:expected) { (::IO.read output_file).chomp }
      it %(when content contains #{scenario_name}) do
        (expect doc.to_asciidoc).to eql expected
      end
    end
  end
end
