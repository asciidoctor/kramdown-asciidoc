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

    it 'encodes Markdown source to UTF-8' do
      input = %(bien s\u00fbr !).encode Encoding::ISO_8859_1
      output = subject.convert input
      (expect output.encoding).to eql Encoding::UTF_8
      (expect output).to eql %(bien s\u00fbr !\n)
    end

    it 'converts CRLF newlines in Markdown source to LF newlines' do
      input = %(\r\n\r\none\r\ntwo\r\nthree\r\n)
      output = subject.convert input
      (expect output.encoding).to eql Encoding::UTF_8
      (expect output).to eql %(one\ntwo\nthree\n)
    end

    it 'converts CR newlines in Markdown source to LF newlines' do
      input = %(\r\rone\rtwo\rthree\r)
      output = subject.convert input
      (expect output.encoding).to eql Encoding::UTF_8
      (expect output).to eql %(one\ntwo\nthree\n)
    end

    it 'writes AsciiDoc to string path specified by :to option' do
      the_output_file = output_file 'convert-to-string-path.adoc'
      (expect subject.convert 'Converted using the API', to: the_output_file).to be_nil
      (expect (IO.read the_output_file)).to eql %(Converted using the API\n)
    end

    it 'creates intermediary directories when writing to string path specified by :to option' do
      the_output_file = output_file 'path/to/convert-to-string-path.adoc'
      the_output_dir = (Pathname.new the_output_file).dirname
      (expect subject.convert 'Converted using the API', to: the_output_file).to be_nil
      (expect the_output_dir).to exist
    end

    it 'writes AsciiDoc to pathname specified by :to option' do
      the_output_file = Pathname.new output_file 'convert-to-pathname.adoc'
      (expect subject.convert 'Converted using the API', to: the_output_file).to be_nil
      (expect the_output_file.read).to eql %(Converted using the API\n)
    end

    it 'creates intermediary directories when writing to pathname specified by :to option' do
      the_output_file = Pathname.new output_file 'path/to/convert-to-pathname.adoc'
      (expect subject.convert 'Converted using the API', to: the_output_file).to be_nil
      (expect the_output_file.dirname).to exist
    end

    it 'writes AsciiDoc to IO object specified by :to option' do
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
    let(:source) { 'Markdown was *here*, but it has become **AsciiDoc**!' }
    let(:expected_output) { %(Markdown was _here_, but it has become *AsciiDoc*!\n) }
    let!(:the_source_file) { (output_file %(convert-file-api-#{object_id}.md)).tap {|file| IO.write file, source } }

    it 'converts Markdown file to AsciiDoc file' do
      the_output_file = output_file %(convert-file-api-#{object_id}.adoc)
      (expect subject.convert_file the_source_file).to be_nil
      (expect Pathname.new the_output_file).to exist
      (expect (IO.read the_output_file)).to eql expected_output
    end

    it 'writes output file to string path specified by :to option' do
      the_output_file = output_file 'convert-file-to-string-path.adoc'
      (expect subject.convert_file the_source_file, to: the_output_file).to be_nil
      (expect (IO.read the_output_file)).to eql expected_output
    end

    it 'creates intermediary directories when writing to string path specified by :to option' do
      the_output_file = output_file 'path/to/convert-file-to-string-path.adoc'
      the_output_dir = (Pathname.new the_output_file).dirname
      (expect subject.convert_file the_source_file, to: the_output_file).to be_nil
      (expect the_output_dir).to exist
    end

    it 'writes output file to pathname specified by :to option' do
      the_output_file = Pathname.new output_file 'convert-file-to-pathname.adoc'
      (expect subject.convert_file the_source_file, to: the_output_file).to be_nil
      (expect (the_output_file.read)).to eql expected_output
    end

    it 'creates intermediary directories when writing to pathname specified by :to option' do
      the_output_file = Pathname.new output_file 'path/to/convert-file-to-pathname.adoc'
      (expect subject.convert_file the_source_file, to: the_output_file).to be_nil
      (expect the_output_file.dirname).to exist
    end

    it 'returns output as string if value of :to option is falsy' do
      (expect subject.convert_file the_source_file, to: nil).to eql expected_output
    end

    it 'writes output to IO object specified by :to option' do
      output_sink = StringIO.new
      (expect subject.convert_file the_source_file, to: output_sink).to be_nil
      (expect output_sink.string).to eql expected_output
    end

    it 'writes output file as UTF-8 regardless of default external encoding' do
      source = %(tr\u00e8s bien !)
      the_output_file = output_file 'force-encoding.adoc'
      script_file = output_file 'force-encoding.rb'
      IO.write script_file, <<~EOS
      require 'kramdown-asciidoc'
      Kramdoc.convert '#{source}', to: '#{the_output_file}'
      EOS
      # NOTE internal encoding must also be set for test to work on JRuby
      `#{ruby} -E ISO-8859-1:ISO-8859-1 #{Shellwords.escape script_file}`
      (expect IO.read the_output_file, mode: 'r:UTF-8').to eql %(#{source}\n)
    end

    it 'passes result through postprocess callback if given' do
      the_output_file = output_file %(convert-file-api-#{object_id}.adoc)
      postprocess = -> (asciidoc) { asciidoc.gsub 'become', 'become glorious' }
      (expect subject.convert_file the_source_file, postprocess: postprocess).to be_nil
      (expect Pathname.new the_output_file).to exist
      (expect (IO.read the_output_file)).to eql %(Markdown was _here_, but it has become glorious *AsciiDoc*!\n)
    end

    it 'passes krawdown document to postprocess method if arity is not 1' do
      the_output_file = output_file %(convert-file-api-#{object_id}.adoc)
      postprocess = -> (asciidoc, kramdown_doc) { asciidoc.gsub 'Markdown', kramdown_doc.options[:input] }
      (expect subject.convert_file the_source_file, postprocess: postprocess).to be_nil
      (expect Pathname.new the_output_file).to exist
      (expect (IO.read the_output_file)).to eql %(GFM was _here_, but it has become *AsciiDoc*!\n)
    end

    it 'uses original source if postprocess callback returns falsy' do
      the_output_file = output_file %(convert-file-api-#{object_id}.adoc)
      postprocess = -> (asciidoc) { nil }
      (expect subject.convert_file the_source_file, postprocess: postprocess).to be_nil
      (expect Pathname.new the_output_file).to exist
      (expect (IO.read the_output_file)).to eql %(Markdown was _here_, but it has become *AsciiDoc*!\n)
    end
  end
end

describe Kramdoc do
  it 'supports Kramdoc as an alias for Kramdown::AsciiDoc' do
    (expect Kramdoc).to eql Kramdown::AsciiDoc
  end

  it 'can be required using the alias kramdoc' do
    require 'kramdoc'
  end
end
