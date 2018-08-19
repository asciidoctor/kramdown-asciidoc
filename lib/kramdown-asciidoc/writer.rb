module Kramdown; module AsciiDoc
  class Writer
    LF = ?\n

    attr_accessor :doctitle
    attr_reader :body

    def initialize
      @prologue = []
      @doctitle = nil
      @attributes = {}
      @body = []
      @nesting_stack = []
      @block_delimiter = nil
      @block_separator = ['']
      @list_level = { list: 0, dlist: 0 }
    end

    def add_attributes new_attributes
      @attributes.update new_attributes
    end

    def add_prologue_line line
      @prologue << line
    end

    def add_prologue_lines lines
      @prologue.push(*lines)
    end

    def start_block
      @body << @block_separator[-1] unless empty?
      nil
    end

    def start_delimited_block delimiter
      @body << (@block_delimiter = delimiter.length == 1 ? delimiter * 4 : delimiter)
      @nesting_stack << [(@body.pop @body.length), @block_delimiter, @block_separator, @list_level]
      @block_separator = ['']
      @list_level = { list: 0, dlist: 0 }
      nil
    end

    def end_delimited_block
      parent_body, @block_delimiter, @block_separator, @list_level = @nesting_stack.pop
      @body = (parent_body + @body) << @block_delimiter
      @block_delimiter = nil
      nil
    end

    # Q: perhaps do_in_list that takes a block?
    def start_list compound, kin
      # Q: can this be further optimized?
      @body << '' if in_list? ? compound : !empty?
      @block_separator << '+'
      @list_level[kin] += 1
      nil
    end

    def end_list kin
      @block_separator.pop
      @list_level[kin] -= 1
      nil
    end

    def list_level kin = :list
      @list_level[kin]
    end

    def in_list?
      @block_separator[-1] == '+'
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

    def clear_line
      replace_line ''
    end

    def replace_line line
      @body.pop
      @body << line
      nil
    end

    def current_line
      @body[-1]
    end

    def empty?
      @body.empty?
    end

    def to_s
      header = @prologue.dup
      header << %(= #{@doctitle}) if @doctitle
      @attributes.sort.each do |name, val|
        header << (val.empty? ? %(:#{name}:) : %(:#{name}: #{val}))
      end unless @attributes.empty?
      (header.empty? ? @body : (header + (@body.empty? ? [] : [''] + @body))).join LF
    end
  end
end; end
