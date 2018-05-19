require_relative 'spec_helper'

describe Kramdown::Converter::AsciiDoc do
  let(:opts) { Kramdown::Converter::AsciiDoc::DEFAULT_PARSER_OPTS }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }
  subject { described_class.send :new, root, {} }

  describe '#convert_p' do
    context 'when paragraph starts with admonition label' do
      let :input do
        <<~EOS.chomp
        Note: Remember the milk!
        EOS
      end
      let :expected do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected
      end
    end

    context 'when paragraph starts with emphasized admonition label' do
      let :input do
        <<~EOS.chomp
        *Note:* Remember the milk!
        EOS
      end
      let :expected do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected
      end
    end

    context 'when paragraph starts with strong admonition label' do
      let :input do
        <<~EOS.chomp
        **Note:** Remember the milk!
        EOS
      end
      let :expected do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected
      end
    end

    context 'when paragraph starts with emphasized admonition label and colon is outside of formatted text' do
      let :input do
        <<~EOS.chomp
        *Note*: Remember the milk!
        EOS
      end
      let :expected do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected
      end
    end
  end

  describe '#convert_native' do
    let(:input) { '<p><b>bold</b> <em>italic</em> <code>mono</code></p>' }
    let(:expected) { '*bold* _italic_ `mono`' }
    it 'should convert HTML to formatted AsciiDoc' do
      (expect doc.to_asciidoc).to eq expected
    end
  end
end
