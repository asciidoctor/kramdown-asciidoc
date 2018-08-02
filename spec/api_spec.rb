require_relative 'spec_helper'

describe Kramdown::AsciiDoc do
  context '#convert' do
    it 'converts Markdown to AsciiDoc' do
      input = <<~EOS
      ---
      title: Document Title
      ---

      Body content.
      EOS

      expected = <<~EOS
      = Document Title

      Body content.
      EOS

      (expect subject.convert input).to eql expected
    end

    it 'writes AsciiDoc to filename specified in :to option' do
      the_output_file = output_file 'convert-api.adoc'
      (expect subject.convert 'Converted using the API', to: the_output_file).to be_nil
      (expect (IO.read the_output_file)).to eql %(Converted using the API\n)
    end

    it 'writes AsciiDoc to IO object specified in :to option' do
      old_stdout, $stdout = $stdout, StringIO.new
      begin
        (expect subject.convert 'text', to: $stdout).to be_nil
        (expect $stdout.string).to eql %(text\n)
      ensure
        $stdout = old_stdout
      end
    end

    it 'adds line feed (EOL) to end of output document if non-empty' do
      (expect subject.convert 'paragraph').to end_with ?\n
    end

    it 'does not add line feed (EOL) to end of output document if empty' do
      (expect subject.convert '').to be_empty
    end
  end

  context '#convert_file' do
    it 'converts Markdown file to AsciiDoc file' do
      the_source_file = output_file 'convert-file-api.md'
      the_output_file = output_file 'convert-file-api.adoc'
      IO.write the_source_file, 'Converted using the API'
      (expect subject.convert_file the_source_file).to be_nil
      (expect (IO.read the_output_file)).to eql %(Converted using the API\n)
    end
  end
end

describe Kramdoc do
  it 'supports Kramdoc as an alias for Kramdown::AsciiDoc' do
    (expect Kramdoc).to eql Kramdown::AsciiDoc
  end
end
