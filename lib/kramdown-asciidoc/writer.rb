module Kramdown; module AsciiDoc
  class Writer
    LF = ?\n

    attr_accessor :header
    attr_reader :body

    def initialize
      @header = []
      @body = []
      @nesting_stack = []
      @block_delimiter = nil
      @block_separator = ''
    end

    def doctitle
      if (doctitle_line = @header.find {|l| l.start_with? '= ' })
        doctitle_line.slice 2, doctitle_line.length
      end
    end

    def doctitle= new_doctitle
      if (doctitle_idx = @header.index {|l| l.start_with? '= ' })
        @header[doctitle_idx] = %(= #{new_doctitle})
      else
        @header.unshift %(= #{new_doctitle})
      end
      nil
    end

    def add_attributes attributes
      attributes.each {|k, v| add_attribute k, v }
      nil
    end

    def add_attribute name, value
      @header << %(:#{name}:#{value.empty? ? '' : ' ' + value.to_s})
      nil
    end

    def start_block
      @body << @block_separator unless empty?
      nil
    end

    # Q: perhaps in_list that takes a block?
    # Q: should we keep stack of list depth?
    def start_list compound_nested = false
      @body << '' unless compound_nested || empty?
      @block_separator = '+'
      nil
    end

    def end_list nested = false
      @block_separator = '' unless nested
      nil
    end

    def start_delimited_block delimiter
      @body << (@block_delimiter = delimiter.length == 1 ? delimiter * 4 : delimiter)
      @nesting_stack << [(@body.pop @body.length), @block_delimiter, @block_separator]
      @block_separator = ''
      nil
    end

    def end_delimited_block
      parent_body, @block_delimiter, @block_separator = @nesting_stack.pop
      @body = (parent_body + @body) << @block_delimiter
      @block_delimiter = nil
      nil
    end

    def clear_line
      @body[-1] = '' unless empty?
      nil
    end

    def add_blank_line
      @body << ''
      nil
    end

    def add_line line
      @body << line
      nil
    end

    def add_lines lines
      @body += lines
      nil
    end

    def append str
      if empty?
        @body << str
      else
        @body[-1] += str
      end
      nil
    end

    def current_line
      @body[-1]
    end

    def empty?
      @body.empty?
    end

    def to_s
      ((@header.empty? ? @body : (@header + (@body.empty? ? [] : ['']) + @body)).join LF) + LF
    end
  end
end; end
