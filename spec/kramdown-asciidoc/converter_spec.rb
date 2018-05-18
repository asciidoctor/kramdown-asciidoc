require 'spec_helper'

describe Kramdown::Converter::Asciidoc do
  let(:opts) { { auto_ids: false, html_to_native: true, input: 'GFM' } }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }
  subject { described_class.send :new, root, {} }

  describe '#convert' do
    let :input do
      <<~EOS.chomp
      # Document Title

      content
      EOS
    end
    let :expected_output do
      <<~EOS.chomp
      = Document Title

      content
      EOS
    end
    it 'should convert Markdown input to AsciiDoc' do
      (expect doc.to_asciidoc).to eq expected_output
    end
  end

  describe '#convert_root' do
    let :input do
      <<~EOS.chomp
      # Document Title

      content
      EOS
    end
    let :expected_output do
      <<~EOS.chomp
      = Document Title

      content
      EOS
    end
    it 'should convert every element' do
      (expect subject.convert_root root, {}).to eq expected_output
    end
  end

  describe '#convert_header' do
    context 'when level is 1' do
      let(:input) { '# Heading' }
      let(:expected_output) { %(= Heading\n\n) }

      it 'should convert level 1 heading to level 0 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end

    context 'when level is 2' do
      let(:input) { '## Heading' }
      let(:expected_output) { %(== Heading\n\n) }

      it 'should convert level 2 heading to level 1 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end

    context 'when level is 3' do
      let(:input) { '### Heading' }
      let(:expected_output) { %(=== Heading\n\n) }

      it 'should convert level 3 heading to level 2 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end

    context 'when level is 4' do
      let(:input) { '#### Heading' }
      let(:expected_output) { %(==== Heading\n\n) }

      it 'should convert level 4 heading to level 3 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end

    context 'when level is 5' do
      let(:input) { '##### Heading' }
      let(:expected_output) { %(===== Heading\n\n) }

      it 'should convert level 5 heading to level 4 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end

    context 'when level is 6' do
      let(:input) { '###### Heading' }
      let(:expected_output) { %(====== Heading\n\n) }

      it 'should convert level 6 heading to level 5 section title' do
        (expect subject.convert_header root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_p' do
    context 'when paragraph is normal' do
      let :input do
        <<~EOS.chomp
        A normal paragraph.
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        A normal paragraph.\n\n
        EOS
      end
      it 'should leave paragraph as is' do
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end

    context 'when paragraph starts with admonition label' do
      let :input do
        <<~EOS.chomp
        Note: Remember the milk!
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end

    context 'when paragraph starts with emphasized admonition label' do
      let :input do
        <<~EOS.chomp
        *Note:* Remember the milk!
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end

    context 'when paragraph starts with strong admonition label' do
      let :input do
        <<~EOS.chomp
        **Note:** Remember the milk!
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        NOTE: Remember the milk!\n\n
        EOS
      end
      it 'should promote paragraph to admonition paragraph' do
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_ul' do
    context 'when not nested' do
      let :input do
        <<~EOS.chomp
        * bread
        * milk
        * eggs
        EOS
      end
      let :expected_output do
        <<~EOS
        * bread
        * milk
        * eggs\n
        EOS
      end
      it 'should convert to lines with leading asterisks' do
        (expect subject.convert_ul root.children.first, {}).to eq expected_output
      end
    end

    context 'when nested' do
      let :input do
        <<~EOS.chomp
        * bread
          * white
          * sourdough
          * rye
        * milk
          * 2%
          * whole
          * soy
        * eggs
          * white
          * brown
        EOS
      end
      let :expected_output do
        <<~EOS
        * bread
        ** white
        ** sourdough
        ** rye
        * milk
        ** 2%
        ** whole
        ** soy
        * eggs
        ** white
        ** brown\n
        EOS
      end
      it 'should increase number of asterisks per level' do
        (expect subject.convert_ul root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_img' do
    context 'when image is inline' do
      let(:input) { 'See the ![Rate of Growth](rate-of-growth.png)' }

      it 'should convert to inline image' do
        expected_output = 'image:rate-of-growth.png[Rate of Growth]'
        p = root.children.first
        (expect subject.convert_img p.children.last, { parent: p }).to eq expected_output
      end

      it 'should put inline image adjacent to text' do
        expected_output = %(See the image:rate-of-growth.png[Rate of Growth]\n\n)
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end

    context 'when image is only element in paragraph' do
      let(:input) { '![Rate of Growth](rate-of-growth.png)' }

      it 'should convert to block image' do
        expected_output = %(image::rate-of-growth.png[Rate of Growth]\n\n)
        (expect subject.convert_p root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_codeblock' do
    context 'when code block is fenced' do
      let :input do
        <<~EOS.chomp
        ```
        All your code.
        
        Belong to us.
        ```
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        ----
        All your code.
        
        Belong to us.
        ----\n\n
        EOS
      end
      it 'should convert to listing block' do
        (expect subject.convert_codeblock root.children.first, {}).to eq expected_output
      end
    end

    context 'when code block is fenced with language' do
      let :input do
        <<~EOS.chomp
        ```java
        public class AllYourCode {
          public String getBelongsTo() {
            return "Us.";
          }
        }
        ```
        EOS
      end
      let :expected_output do
        <<~EOS.chomp
        [source,java]
        ----
        public class AllYourCode {
          public String getBelongsTo() {
            return "Us.";
          }
        }
        ----\n\n
        EOS
      end
      it 'should convert to source block with language' do
        (expect subject.convert_codeblock root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_codeblock' do
    context 'when horizontal rule is found' do
      let(:input) { '---' }
      let(:expected_output) { %('''\n\n) }
      it 'should convert to thematic break' do
        (expect subject.convert_hr root.children.first, {}).to eq expected_output
      end
    end
  end

  describe '#convert_native' do
    let(:input) { '<p><b>bold</b> <em>italic</em> <code>mono</code></p>' }
    let(:expected_output) { '*bold* _italic_ `mono`' }
    it 'should convert HTML to formatted AsciiDoc' do
      (expect doc.to_asciidoc).to eq expected_output
    end
  end
end
