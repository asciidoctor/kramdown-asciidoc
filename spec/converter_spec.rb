require_relative 'spec_helper'

describe Kramdown::AsciiDoc::Converter do
  let(:opts) { Kramdown::AsciiDoc::DEFAULT_PARSER_OPTS }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }
  let(:converter) { described_class.send :new, root, {} }

  context '#convert' do
    let (:input) { %(# Document Title\n\nBody text.) }

    it 'adds line feed (EOL) to end of output document' do
      (expect converter.convert root).to end_with %(\n)
      (expect doc.to_asciidoc).to end_with %(\n)
    end

    # Q: can we find a scenario that covers this?
    it 'does not crash if element is nil' do
      (expect converter.convert nil).to be_nil
    end
  end

  context '#clone' do
    let :input do
      <<~EOS
      ## <a id="anchor-name">Heading Title</a>

      Note: Be mindful.

      *Important*: Turn off the lights.
      EOS
    end

    it 'does not modify the AST when converting' do
      doc.to_asciidoc
      heading = root.children[0]
      (expect heading.children[0].type).to be :html_element
      (expect heading.children[0].value).to eql 'a'
      para_i = root.children[2]
      (expect para_i.children[0].value).to start_with 'Note: '
      para_ii = root.children[4]
      (expect para_ii.children[0].type).to be :em
    end
  end

  context '.replace_toc' do
    it 'does not modify source if TOC directive not detected' do
      input = <<~EOS
      # Database Guide

      ...
      EOS

      (expect Kramdown::AsciiDoc.replace_toc input, (attributes = {})).to be input
      (expect attributes).to be_empty
    end

    it 'replaces TOC directive with a toc block macro' do
      input = <<~EOS
      # Database Guide

      This tutorial walks you through the steps to set up a database instance.

      <!-- TOC depthFrom:2 depthTo:6 withLinks:1 updateOnSave:1 -->

      - [Prerequisites](#prerequisites)
      - [Create an Instance](#1-create-instance)
      - [Create a User](#2-create-user)
      	- [Create a user using the CLI](#create-user-using-cli)
      	- [Create a user using the UI](#create-user-using-ui)
      - [Insert Data](#3-insert-data)
      - [Start Instance](#4-start-instance)

      <!-- /TOC -->

      ...
      EOS

      expected = <<~EOS
      # Database Guide

      This tutorial walks you through the steps to set up a database instance.

      toc::[]

      ...
      EOS

      (expect Kramdown::AsciiDoc.replace_toc input, (attributes = {})).to eql expected
      (expect attributes['toc']).to eql 'macro'
    end
  end

  context '.extract_front_matter' do
    it 'does not modify source if front matter not detected' do
      input = <<~EOS
      # Introduction

      content

      ---

      more content
      EOS

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to be input
      (expect attributes).to be_empty
    end

    it 'does not modify source if source is empty' do
      input = ''

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to be input
      (expect attributes).to be_empty
    end

    it 'extracts front matter and assigns entries to attributes' do
      input = <<~EOS
      ---
      title: Introduction From Front Matter
      description: An introduction to this amazing technology.
      keywords: buzz, transformative
      layout: default
      ---
      # Introduction

      When using this technology, anything is possible.
      EOS

      expected = <<~EOS
      # Introduction

      When using this technology, anything is possible.
      EOS

      expected_attributes = {
        'title' => 'Introduction From Front Matter',
        'description' => 'An introduction to this amazing technology.',
        'keywords' => 'buzz, transformative',
      }

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to eql expected
      (expect attributes).to eql expected_attributes
    end

    it 'ignores title from front matter if explicit document title is present' do
      input = <<~EOS
      ---
      title: Document Title From Front Matter
      description: An introduction to this amazing technology.
      ---
      # Introduction

      When using this technology, anything is possible.
      EOS

      expected = <<~EOS
      = Introduction
      :description: An introduction to this amazing technology.

      When using this technology, anything is possible.
      EOS

      # FIXME can we reuse our lets to handle this test?
      input = Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})
      doc = Kramdown::Document.new input, (opts.merge attributes: attributes)
      (expect doc.to_asciidoc).to eql expected
    end

    it 'uses title from front matter as document title if explicit document title is absent' do
      input = <<~EOS
      ---
      title: Introduction
      description: An introduction to this amazing technology.
      ---

      When using this technology, anything is possible.
      EOS

      expected = <<~EOS
      = Introduction
      :description: An introduction to this amazing technology.

      When using this technology, anything is possible.
      EOS

      # FIXME can we reuse our lets to handle this test?
      input = Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})
      doc = Kramdown::Document.new input, (opts.merge attributes: attributes)
      (expect doc.to_asciidoc).to eql expected
    end

    it 'assigns non-default layout in front matter to page-layout attribute' do
      input = <<~EOS
      ---
      layout: home
      ---
      Welcome home!
      EOS

      expected = <<~EOS
      Welcome home!
      EOS

      expected_attributes = {
        'page-layout' => 'home'
      }

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to eql expected
      (expect attributes).to eql expected_attributes
    end

    it 'returns empty document when it only contains front matter' do
      input = <<~EOS
      ---
      description: This page is intentionally left blank.
      ---
      EOS

      expected_attributes = {
        'description' => 'This page is intentionally left blank.'
      }

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to be_empty
      (expect attributes).to eql expected_attributes
    end

    it 'removes empty front matter' do
      input = <<~EOS
      ---
      ---
      Move along. There's no front matter to see here.
      EOS

      expected = <<~EOS
      Move along. There's no front matter to see here.
      EOS

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to eql expected
      (expect attributes).to be_empty
    end

    it 'does not remove leading hr' do
      input = '---'

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to eql input
      (expect attributes).to be_empty
    end

    it 'removes blank lines between front matter and body' do
      input = <<~EOS
      ---
      description: Just another page.
      ---

      Another page.
      EOS

      expected = <<~EOS
      Another page.
      EOS

      expected_attributes = {
        'description' => 'Just another page.'
      }

      (expect Kramdown::AsciiDoc.extract_front_matter input, (attributes = {})).to eql expected
      (expect attributes).to eql expected_attributes
    end
  end
end
