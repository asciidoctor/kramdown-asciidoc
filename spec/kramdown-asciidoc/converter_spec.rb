require 'spec_helper'

describe Kramdown::Converter::Asciidoc do
  let(:opts) { { input: 'GFM' } }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }
  subject { described_class.send :new, root, {} }

  describe '#convert' do
    let(:input) { <<EOS.chomp
# Document Title

content
EOS
    }
    let(:expected_output) { <<EOS.chomp
= Document Title

content
EOS
    }
    it 'should convert Markdown input to AsciiDoc' do
      expect(doc.to_asciidoc).to eq(expected_output) 
    end
  end

  describe '#convert_root' do
    let(:input) { <<EOS.chomp
# Document Title

content
EOS
    }
    let(:expected_output) { <<EOS.chomp
= Document Title

content
EOS
    }
    it 'should convert every element' do
      expect(subject.convert_root root, {}).to eq(expected_output)
    end
  end

  describe '#convert_header' do
    context 'when level is 1' do
      let(:input) { '# Header' }
      let(:expected_output) { %(= Header\n\n) }

      it 'should convert level 1 header to level 0 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when level is 2' do
      let(:input) { '## Header' }
      let(:expected_output) { %(== Header\n\n) }

      it 'should convert level 2 header to level 1 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when level is 3' do
      let(:input) { '### Header' }
      let(:expected_output) { %(=== Header\n\n) }

      it 'should convert level 3 header to level 2 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when level is 4' do
      let(:input) { '#### Header' }
      let(:expected_output) { %(==== Header\n\n) }

      it 'should convert level 4 header to level 3 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when level is 5' do
      let(:input) { '##### Header' }
      let(:expected_output) { %(===== Header\n\n) }

      it 'should convert level 5 header to level 4 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when level is 6' do
      let(:input) { '###### Header' }
      let(:expected_output) { %(====== Header\n\n) }

      it 'should convert level 6 header to level 5 section' do
        expect(subject.convert_header root.children.first, {}).to eq(expected_output)
      end
    end
  end

  describe '#convert_ul' do
    context 'when not nested' do
      let(:input) { <<EOS.chomp
* bread
* milk
* eggs
EOS
      }
      let(:expected_output) { <<EOS
* bread
* milk
* eggs

EOS
      }
      it 'should convert to lines with leading asterisks' do
        expect(subject.convert_ul root.children.first, {}).to eq(expected_output)
      end
    end

    context 'when nested' do
      let(:input) { <<EOS.chomp
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
      }
      let(:expected_output) { <<EOS
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
** brown

EOS
      }
      it 'should increase number of asterisks per level' do
        expect(subject.convert_ul root.children.first, {}).to eq(expected_output)
      end
    end
  end
end
