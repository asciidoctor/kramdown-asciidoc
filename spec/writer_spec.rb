require_relative 'spec_helper'

describe Kramdown::AsciiDoc::Writer do
  it 'replaces existing doctitle if present when assigning doctitle' do
    header_lines = ['[#docid]', '= Document Title', ':experimental:']
    subject.header.push(*header_lines)
    subject.doctitle = 'New Document Title'
    (expect subject.doctitle).to eql 'New Document Title'
  end
end
