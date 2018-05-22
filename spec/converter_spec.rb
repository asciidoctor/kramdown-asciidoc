require_relative 'spec_helper'

describe Kramdown::Converter::AsciiDoc do
  let(:opts) { Kramdown::Converter::AsciiDoc::DEFAULT_PARSER_OPTS }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }

  context '#convert' do
    let (:input) { %(# Document Title\n\nBody text.) }
    it 'adds line feed (EOL) to end of output document' do
      converter = described_class.send :new, root, {}
      (expect converter.convert root).to end_with %(\n)
      (expect doc.to_asciidoc).to end_with %(\n)
    end
  end

  context '.replace_toc' do
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

      attributes = {}
      (expect described_class.replace_toc input, attributes).to eql expected
      (expect attributes['toc']).to eql 'macro'
    end
  end

  context '.extract_front_matter' do
    it 'extracts front matter and assigns entries to attributes' do
      input = <<~EOS
      ---
      title: Introduction
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
        'description' => 'An introduction to this amazing technology.',
        'keywords' => 'buzz, transformative',
      }

      attributes = {}
      (expect described_class.extract_front_matter input, attributes).to eql expected
      (expect attributes).to eql expected_attributes
    end
  end
end
