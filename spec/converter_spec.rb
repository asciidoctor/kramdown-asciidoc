require_relative 'spec_helper'

describe Kramdown::Converter::AsciiDoc do
  let(:opts) { Kramdown::Converter::AsciiDoc::DEFAULT_PARSER_OPTS }
  let(:doc) { Kramdown::Document.new input, opts }
  let(:root) { doc.root }

  context 'TOC' do
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
end
