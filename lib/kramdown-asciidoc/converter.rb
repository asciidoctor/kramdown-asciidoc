# encoding: UTF-8
module Kramdown; module AsciiDoc
  DEFAULT_PARSER_OPTS = {
    auto_ids: false,
    hard_wrap: false,
    html_to_native: true,
    input: 'GFM',
  }

  TocDirectiveTip = '<!-- TOC '
  TocDirectiveRx = /^<!-- TOC .*<!-- \/TOC -->/m

  # TODO return original source if YAML can't be parsed
  def self.extract_front_matter source, attributes
    if (line_i = (lines = source.each_line).first) && line_i.chomp == '---'
      lines = lines.drop 1
      front_matter = []
      while (line = lines.shift) && line.chomp != '---'
        front_matter << line
      end
      return source unless line && line.chomp == '---' && !(front_matter.include? ?\n)
      lines.shift while (line = lines[0]) && line == ?\n
      (::YAML.load front_matter.join).each do |key, val|
        if key == 'layout'
          attributes['page-layout'] = val unless val == 'default'
        else
          attributes[key] = val.to_s
        end
      end unless front_matter.empty?
      lines.join
    else
      source
    end
  end

  def self.replace_toc source, attributes
    if source.include? TocDirectiveTip
      attributes['toc'] = 'macro'
      source.gsub TocDirectiveRx, 'toc::[]'
    else
      source
    end
  end

  class Converter < ::Kramdown::Converter::Base
    RESOLVE_ENTITY_TABLE = { 38 => '&', 60 => '<', 62 => '>', 124 => '|' }
    ADMON_LABELS = %w(Note Tip Caution Warning Important Attention Hint).map {|l| [l, l] }.to_h
    ADMON_MARKERS = ADMON_LABELS.map {|l, _| %(#{l}: ) }
    ADMON_MARKERS_ASCIIDOC = %w(NOTE TIP CAUTION WARNING IMPORTANT).map {|l| %(#{l}: ) }
    ADMON_FORMATTED_MARKERS = ADMON_LABELS.map {|l, _| [%(#{l}:), l] }.to_h
    ADMON_TYPE_MAP = ADMON_LABELS.map {|l, _| [l, l.upcase] }.to_h.merge 'Attention' => 'IMPORTANT', 'Hint' => 'TIP'
    BLOCK_TYPES = [:p, :blockquote, :codeblock, :table]
    DLIST_MARKERS = %w(:: ;; ::: ::::)
    PUNCTUATION = %w(. ? !)
    # FIXME here we reverse the smart quotes; add option to allow them (needs to be handled carefully)
    SMART_QUOTE_ENTITY_TO_MARKUP = { ldquo: ?", rdquo: ?", lsquo: ?', rsquo: ?' }
    TYPOGRAPHIC_SYMBOL_TO_MARKUP = {
      '“' => '"`',
      '”' => '`"',
      '‘' => '\'`',
      '’' => '`\'',
      # FIXME in the future, mdash will be three dashes in AsciiDoc; for now, down-convert
      '—' => '--',
      '–' => '--',
      '…' => '...',
    }
    TYPOGRAPHIC_ENTITY_TO_MARKUP = {
      # FIXME in the future, mdash will be three dashes in AsciiDoc; for now, down-convert
      mdash: '--',
      ndash: '--',
      hellip: '...',
      laquo: '<<',
      raquo: '>>',
      laquo_scape: '<< ',
      raquo_space: ' >>',
    }
    TABLE_ALIGNMENTS = {
      left: '<',
      center: '^',
      right: '>',
    }

    NON_DEFAULT_TABLE_ALIGNMENTS = [:center, :right]

    CommentPrefixRx = /^ *! ?/m
    CssPropDelimRx = /\s*;\s*/
    FullStopRx = /(?<=\S\.|.\?|.!)\p{Blank}+/
    InadvertentReplacementsRx = /[-=]>|<[-=]|\.\.\.|\{\p{Word}[\p{Word}-]*\}/
    MenuRefRx = /^([\p{Word}&].*?)\s>\s([\p{Word}&].*(?:\s>\s|$))+/
    ReplaceableTextRx = /[-=]>|<[-=]| -- |\p{Word}--\p{Word}|\*\*|\.\.\.|&\S+;|\{\p{Word}[\p{Word}-]*\}|(?:https?|ftp):\/\/\p{Word}|\((?:C|R|TM)\)/
    SmartApostropheRx = /\b’\b/
    TrailingSpaceRx = / +$/
    TypographicSymbolRx = /[“”‘’—–…]/
    UriSchemeRx = /(?:https?|ftp):\/\/\p{Word}/
    WordishRx = /[\p{Word};:<>&]/
    WordRx = /\p{Word}/
    XmlCommentRx = /\A<!--(.*)-->\Z/m

    VoidElement = Element.new nil

    LF = ?\n
    NBSP = ?\u00a0

    def initialize root, opts
      super
      @attributes = opts[:attributes] || {}
      @auto_links = opts.fetch :auto_links, true
      @heading_offset = opts[:heading_offset] || 0
      @imagesdir = opts[:imagesdir] || @attributes['imagesdir']
      @wrap = opts[:wrap] || :preserve
      @current_heading_level = nil
    end

    def convert el, opts = {}
      send %(convert_#{el.type}), el, opts if el
    end

    def convert_root el, opts
      writer = Writer.new
      el = extract_prologue el, (opts.merge writer: writer)
      traverse el, (opts.merge writer: writer)
      if (fallback_doctitle = @attributes.delete 'title')
        writer.doctitle ||= fallback_doctitle
      end
      writer.add_attributes @attributes unless @attributes.empty?
      result = writer.to_s.gsub TrailingSpaceRx, ''
      # QUESTION should we add a preprocessor step to clean the source?
      result = result.tr NBSP, ' ' if result.include? NBSP
      result
    end

    def convert_heading el, opts
      (writer = opts[:writer]).start_block
      level = el.options[:level] + @heading_offset
      style = []
      # Q: should writer track last heading level?
      if (discrete = @current_heading_level && level > @current_heading_level + 1)
        # TODO make block title promotion an option (allow certain levels and titles)
        if level == 5 && (next_2_siblings = (siblings = opts[:parent].children).slice (siblings.index el) + 1, 2) &&
            next_2_siblings.any? {|sibling| sibling.type == :codeblock }
          writer.add_line %(.#{compose_text el, strip: true})
          return
        end
        style << 'discrete'
      end
      if (child_i = to_element el.children[0]).type == :html_element && child_i.value == 'a' && (id = child_i.attr['id'])
        el = clone el, children: child_i.children + (el.children.drop 1)
        style << %(##{id})
      elsif (id = el.attr['id'])
        style << %(##{id})
      end
      if (role = el.attr['class'])
        style << %(.#{role.tr ' ', '.'})
      end
      lines = []
      lines << %([#{style.join}]) unless style.empty?
      # NOTE kramdown removes newlines from heading
      lines << %(#{'=' * level} #{compose_text el, strip: true})
      if level == 1 && writer.empty? && @current_heading_level != 1
        writer.header.push(*lines)
        nil
      else
        @attributes['doctype'] = 'book' if level == 1
        writer.add_lines lines
      end
      @current_heading_level = level unless discrete
      nil
    end

    # Kramdown incorrectly uses the term header for headings
    alias convert_header convert_heading

    def convert_blank el, opts
    end

    def convert_p el, opts
      (writer = opts[:writer]).start_block
      if (children = el.children).empty?
        lines = ['{blank}']
      # NOTE detect plain admonition marker (e.g, Note: ...)
      # TODO these conditionals could be optimized
      elsif (child_i = children[0]).type == :text && (child_i_text = child_i.value).start_with?(*ADMON_MARKERS)
        marker, child_i_text = child_i_text.split ': ', 2
        children = [(clone child_i, value: %(#{ADMON_TYPE_MAP[marker]}: #{child_i_text}))] + (children.drop 1)
        lines = compose_text children, parent: el, strip: true, split: true, wrap: @wrap
      # NOTE detect formatted admonition marker (e.g., *Note:* ...)
      elsif (child_i.type == :strong || child_i.type == :em) &&
          (marker_el = child_i.children[0]) && ((marker = ADMON_FORMATTED_MARKERS[marker_el.value]) ||
          ((marker = ADMON_LABELS[marker_el.value]) && (child_ii = to_element children[1]).type == :text &&
          ((child_ii_text = child_ii.value).start_with? ': ')))
        children = children.drop 1
        children[0] = clone child_ii, value: (child_ii_text.slice 1, child_ii_text.length) if child_ii
        # Q: should we only rstrip?
        lines = compose_text children, parent: el, strip: true, split: true, wrap: @wrap
        lines.unshift %(#{ADMON_TYPE_MAP[marker]}: #{lines.shift})
      else
        lines = compose_text el, strip: true, split: true, wrap: @wrap
      end
      writer.add_lines lines
    end

    # Q: should we delete blank line between blocks in a nested conversation?
    # TODO use shorthand for blockquote when contents is paragraph only; or always?
    def convert_blockquote el, opts
      (writer = opts[:writer]).start_block
      traverse el, (opts.merge writer: (block_writer = Writer.new), blockquote_depth: (depth = opts[:blockquote_depth] || 0) + 1)
      contents = block_writer.body
      if contents[0].start_with?(*ADMON_MARKERS_ASCIIDOC) && !(contents.include? '')
        writer.add_lines contents
      else
        if contents.size > 1 && (contents[-1].start_with? '-- ')
          attribution = (attribution_line = contents.pop).slice 3, attribution_line.length
          writer.add_line %([,#{attribution}])
          # NOTE there will be at least one non-blank line, but coerce .to_s just to be safe
          contents.pop while contents[-1].to_s.empty?
        end
        # Q: should writer handle delimited block nesting?
        delimiter = depth > 0 ? ('____' + '__' * depth) : '_'
        writer.start_delimited_block delimiter
        writer.add_lines contents
        writer.end_delimited_block
      end
    end

    # TODO match logic from ditarx
    def convert_codeblock el, opts
      writer = opts[:writer]
      # NOTE hack to down-convert level-5 heading to block title
      if (current_line = writer.current_line) && (!(current_line.start_with? '.') || (current_line.start_with? '. '))
        writer.start_block
      end
      lines = el.value.rstrip.split LF
      if (lang = el.attr['class'])
        # NOTE Kramdown always prefixes class with language-
        # TODO remap lang if requested
        writer.add_line %([source,#{lang = lang.slice 9, lang.length}])
      elsif (prompt = lines[0].start_with? '$ ')
        writer.add_line %([source,#{lang = 'console'}]) if lines.include? ''
      end
      if lang || (el.options[:fenced] && !prompt)
        writer.add_line '----'
        writer.add_lines lines
        writer.add_line '----'
      elsif !prompt && (lines.include? '')
        writer.add_line '....'
        writer.add_lines lines
        writer.add_line '....'
      else
        # NOTE clear the list continuation
        writer.clear_line if writer.current_line == '+'
        writer.add_line lines.map {|l| %( #{l}) }
      end
    end

    def convert_img el, opts
      if (parent = opts[:parent]).type == :p && parent.children.size == 1
        style = []
        if (id = el.attr['id'])
          style << %(##{id})
        end
        if (role = el.attr['class'])
          style << %(.#{role.tr ' ', '.'})
        end
        block_attributes_line = %([#{style.join}]) unless style.empty?
        block = true
      end
      macro_attrs = [nil]
      if (alt_text = el.attr['alt'])
        macro_attrs[0] = alt_text unless alt_text.empty?
      end
      if (width = el.attr['width'])
        macro_attrs << width
      elsif (css = el.attr['style']) && (width_css = (css.split CssPropDelimRx).find {|p| p.start_with? 'width:' })
        width = (width_css.slice (width_css.index ':') + 1, width_css.length).strip
        width = width.to_f.round unless width.end_with? '%'
        macro_attrs << width
      end
      if macro_attrs.size == 1 && (alt_text = macro_attrs.pop)
        macro_attrs << alt_text
      end
      if (url = opts[:url])
        macro_attrs << %(link=#{url})
      end
      src = el.attr['src']
      if (imagesdir = @imagesdir) && (src.start_with? %(#{imagesdir}/))
        src = src.slice imagesdir.length + 1, src.length
      end
      writer = opts[:writer]
      if block
        writer.start_block
        writer.add_line block_attributes_line if block_attributes_line
        writer.add_line %(image::#{src}[#{macro_attrs.join ','}])
      else
        writer.append %(image:#{src}[#{macro_attrs.join ','}])
      end
    end

    def convert_ul el, opts
      kin = el.type == :dl ? :dlist : :list
      (writer = opts[:writer]).start_list (parent = opts[:parent]).type == :dd || parent.options[:compound], kin
      traverse el, opts
      writer.end_list kin
      writer.add_blank_line if writer.in_list? && opts[:next]
    end

    alias convert_ol convert_ul
    alias convert_dl convert_ul

    def convert_li el, opts
      writer = opts[:writer]
      writer.add_blank_line if (prev = opts[:prev]) && prev.options[:compound]
      marker = opts[:parent].type == :ol ? '.' : '*'
      indent = (level = writer.list_level) - 1
      if (children = el.children)[0].type == :p
        primary, remaining = [(children = children.dup).shift, children]
        primary_lines = compose_text [primary], parent: el, strip: true, split: true, wrap: @wrap
      else
        remaining = children
        primary_lines = ['{blank}']
      end
      primary_lines.unshift %(#{indent > 0 ? ' ' * indent : ''}#{marker * level} #{primary_lines.shift})
      writer.add_lines primary_lines
      unless remaining.empty?
        if remaining.find {|n| (type = n.type) == :blank ? nil : ((BLOCK_TYPES.include? type) ? true : break) }
          el.options[:compound] = true 
        end
        traverse remaining, (opts.merge parent: el)
      end
    end

    def convert_dt el, opts
      writer = opts[:writer]
      # NOTE kramdown removes newlines from term
      term = compose_text el, strip: true
      marker = DLIST_MARKERS[(writer.list_level :dlist) - 1]
      #writer.add_blank_line if (prev = opts[:prev]) && prev.options[:compound]
      writer.add_blank_line if opts[:prev]
      writer.add_line %(#{term}#{marker})
    end

    def convert_dd el, opts
      if el.options[:first_as_para] == false
        remaining = el.children
      else
        remaining = (children = el.children).drop 1
        primary_lines = compose_text [children[0]], parent: el, strip: true, split: true, wrap: @wrap
        if primary_lines.size == 1
          opts[:writer].append %( #{primary_lines[0]})
        else
          el.options[:compound] = true
          opts[:writer].add_lines primary_lines
        end
      end
      unless remaining.empty?
        if remaining.find {|n| (type = n.type) == :blank ? nil : ((BLOCK_TYPES.include? type) ? true : break) }
          el.options[:compound] = true
        end
        traverse remaining, (opts.merge parent: el)
      end
    end

    def convert_table el, opts
      head = nil
      cols = (alignments = el.options[:alignment]).size
      if alignments.any? {|align| NON_DEFAULT_TABLE_ALIGNMENTS.include? align }
        colspecs = alignments.map {|align| TABLE_ALIGNMENTS[align] }.join ','
        colspecs = %("#{colspecs}") if cols > 1
      end
      table_buffer = ['|===']
      ventilate = @wrap == :ventilate
      el.children.each do |container|
        container.children.each do |row|
          row_buffer = []
          row.children.each do |cell|
            if ventilate
              cell_contents = (compose_text cell, split: true, wrap: :ventilate).map do |line|
                (line.include? '|') ? (line.gsub '|', '\|') : line
              end
              cell_contents[0] = %(| #{cell_contents[0]})
              row_buffer += cell_contents
            else
              cell_contents = compose_text cell
              cell_contents = cell_contents.gsub '|', '\|' if cell_contents.include? '|'
              row_buffer << %(| #{cell_contents})
            end
          end
          if container.type == :thead
            head = true
            row_buffer = [row_buffer * ' ', '']
          elsif cols > 1
            row_buffer << ''
          end
          table_buffer.concat row_buffer
        end
      end
      table_buffer.pop if table_buffer[-1] == ''
      table_buffer << '|==='
      (writer = opts[:writer]).start_block
      if colspecs
        writer.add_line %([cols=#{colspecs}])
      elsif !head && cols > 1
        writer.add_line %([cols=#{cols}*])
      end
      opts[:writer].add_lines table_buffer
    end

    def convert_hr el, opts
      (writer = opts[:writer]).start_block
      writer.add_line '\'\'\''
    end

    def convert_a el, opts
      if (url = el.attr['href']).start_with? '#'
        opts[:writer].append %(<<#{url.slice 1, url.length},#{compose_text el, strip: true}>>)
      elsif url.start_with? 'https://', 'http://'
        if (children = el.children).size == 1 && (child_i = el.children[0]).type == :img
          convert_img child_i, parent: opts[:parent], index: 0, url: url, writer: opts[:writer]
        else
          bare = ((text = compose_text el, strip: true).chomp '/') == (url.chomp '/')
          url = url.gsub '__', '%5F%5F' if (url.include? '__')
          opts[:writer].append bare ? url : %(#{url}[#{text.gsub ']', '\]'}])
        end
      elsif url.end_with? '.md'
        text = (compose_text el, strip: true).gsub ']', '\]'
        text = %(#{text.slice 0, text.length - 3}.adoc) if text.end_with? '.md'
        opts[:writer].append %(xref:#{url.slice 0, url.length - 3}.adoc[#{text}])
      else
        opts[:writer].append %(link:#{url}[#{(compose_text el, strip: true).gsub ']', '\]'}])
      end
    end 

    def convert_codespan el, opts
      attrlist, mark = '', '`'
      if unconstrained? (prev_el = opts[:prev]), (next_el = opts[:next])
        mark = '``'
      elsif next_el
        case next_el.type
        when :smart_quote
          if prev_el && prev_el.type == :smart_quote
            attrlist, mark = '[.code]', '``'
          else
            mark = '``'
          end
        when :text
          mark = '``' if (next_el.value.chr == ?') || (prev_el && prev_el.type == :smart_quote)
        end
      end
      text = el.value
      pass = (replaceable? text) ? :shorthand : nil
      pass = :macro if text.include? '++'
      if pass == :shorthand
        opts[:writer].append %(#{mark}+#{text}+#{mark})
      elsif pass == :macro
        opts[:writer].append %(#{mark}pass:c[#{text}]#{mark})
      else
        opts[:writer].append %(#{attrlist}#{mark}#{text}#{mark})
      end
    end

    def convert_em el, opts
      composed_text = compose_text el
      mark = (unconstrained? opts[:prev], opts[:next]) ? '__' : '_'
      opts[:writer].append %(#{mark}#{composed_text}#{mark})
    end

    def convert_strong el, opts
      if ((composed_text = compose_text el).include? ' > ') && MenuRefRx =~ composed_text
        @attributes['experimental'] = ''
        opts[:writer].append %(menu:#{$1}[#{$2}])
      else
        mark = (unconstrained? opts[:prev], opts[:next]) ? '**' : '*'
        opts[:writer].append %(#{mark}#{composed_text}#{mark})
      end
    end

    def unconstrained? prev_el, next_el
      (next_char_word? next_el) || (prev_char_wordish? prev_el)
    end

    def prev_char_wordish? prev_el
      prev_el && (prev_el.type == :entity || (prev_el.type == :text && (WordishRx.match? prev_el.value[-1])))
    end

    def next_char_word? next_el
      next_el && next_el.type == :text && (WordRx.match? next_el.value.chr)
    end

    def convert_text el, opts
      text = escape_replacements el.value
      if text.include? '++'
        @attributes['pp'] = '{plus}{plus}'
        text = text.gsub '++', '{pp}'
      end
      if (current_line = (writer = opts[:writer]).current_line).to_s.empty?
        writer.append text.lstrip
      else
        writer.append text
      end
    end

    def replaceable? text
      (ReplaceableTextRx.match? text) || (text != '^' && (text.include? '^'))
    end

    def escape_replacements text
      # NOTE the replacement \\\\\& inserts a single backslash in front of the matched text
      text = text.gsub InadvertentReplacementsRx, '\\\\\&' if InadvertentReplacementsRx.match? text
      text = text.gsub UriSchemeRx, '\\\\\&' if !@auto_links && (text.include? '://')
      text = text.gsub '^', '{caret}' if (text.include? '^') && text != '^'
      unless text.ascii_only?
        text = (text.gsub SmartApostropheRx, ?').gsub TypographicSymbolRx, TYPOGRAPHIC_SYMBOL_TO_MARKUP
      end
      text
    end

    # NOTE this logic assumes the :hard_wrap option is disabled in the parser
    def convert_br el, opts
      writer = opts[:writer]
      if writer.empty?
        writer.append '{blank} +'
      else
        writer.append %(#{(writer.current_line.end_with? ' ') ? '' : ' '}+)
      end
      if el.options[:html_tag]
        writer.add_blank_line unless (next_el = to_element opts[:next]).type == :text && (next_el.value.start_with? LF)
      end
    end

    def convert_entity el, opts
      opts[:writer].append RESOLVE_ENTITY_TABLE[el.value.code_point] || el.options[:original]
    end

    def convert_smart_quote el, opts
      opts[:writer].append SMART_QUOTE_ENTITY_TO_MARKUP[el.value]
    end

    # NOTE leave enabled so we can down-convert mdash to --
    def convert_typographic_sym el, opts
      opts[:writer].append TYPOGRAPHIC_ENTITY_TO_MARKUP[el.value]
    end

    def convert_html_element el, opts
      if (tag = el.value) == 'div' && (child_i = el.children[0]) && child_i.options[:transparent] && (child_i_i = child_i.children[0])
        if child_i_i.value == 'span' && ((role = el.attr['class'].to_s).start_with? 'note') && child_i_i.attr['class'] == 'notetitle'
          marker = ADMON_FORMATTED_MARKERS[(to_element child_i_i.children[0]).value] || 'Note'
          lines = compose_text (child_i.children.drop 1), parent: child_i, strip: true, split: true, wrap: @wrap
          lines.unshift %(#{ADMON_TYPE_MAP[marker]}: #{lines.shift})
          opts[:writer].start_block
          opts[:writer].add_lines lines
          return
        else
          return convert_p child_i, (opts.merge parent: el, index: 0)
        end
      end

      contents = compose_text el, (opts.merge strip: el.options[:category] == :block)
      case tag
      when 'del'
        opts[:writer].append %([.line-through]##{contents}#)
      when 'mark'
        opts[:writer].append %(##{contents}#)
      when 'span'
        if (role = el.attr['class'])
          opts[:writer].append %([.#{role.tr ' ', '.'}]##{contents}#)
        else
          opts[:writer].append contents
        end
      when 'sup'
        opts[:writer].append %(^#{contents}^)
      when 'sub'
        opts[:writer].append %(~#{contents}~)
      else
        attrs = (attrs = el.attr).empty? ? '' : attrs.map {|k, v| %( #{k}="#{v}") }.join
        opts[:writer].append %(+++<#{tag}#{attrs}>+++#{contents}+++</#{tag}>+++)
      end
    end

    def convert_xml_comment el, opts
      writer = opts[:writer]
      XmlCommentRx =~ el.value
      lines = (($1.include? ' !') ? ($1.gsub CommentPrefixRx, '').strip : $1.strip).split LF
      #siblings = (parent = opts[:parent]) ? parent.children : []
      if (el.options[:category] == :block)# || (!opts[:result][-1] && siblings[-1] == el)
        writer.start_block
        if lines.empty?
          writer.add_line '//'
        # Q: should we only use block form if empty line is present?
        elsif lines.size > 1
          writer.add_line '////'
          writer.add_lines lines
          writer.add_line '////'
        else
          writer.add_line %(// #{lines[0]})
        end
      elsif !lines.empty?
        if (current_line = writer.current_line) && !(current_line.end_with? LF)
          start_new_line = true
          writer.replace_line current_line.rstrip if current_line.end_with? ' '
        end
        lines = lines.map {|l| %(// #{l}) }
        if start_new_line
          writer.add_lines lines
        else
          writer.append lines.shift
          writer.add_lines lines unless lines.empty?
        end
        writer.add_blank_line
      end
    end

    def extract_prologue el, opts
      if (child_i = to_element (children = el.children)[0]).type == :xml_comment
        (prologue_el = el.dup).children = children.take_while {|child| child.type == :xml_comment || child.type == :blank }
        (el = el.dup).children = children.drop prologue_el.children.size
        traverse prologue_el, (opts.merge writer: (prologue_writer = Writer.new))
        opts[:writer].header.push(*prologue_writer.body)
      end
      el
    end

    def clone el, properties
      el = el.dup
      properties.each do |name, value|
        el.send %(#{name}=).to_sym, value
      end
      el
    end

    def to_element el
      el || VoidElement
    end

    def traverse el, opts
      if ::Array === el
        nodes = el
        parent = opts[:parent]
      else
        nodes = (parent = el).children
      end
      nodes.each_with_index do |child, idx|
        convert child, (opts.merge parent: parent, index: idx, prev: (idx == 0 ? nil : nodes[idx - 1]), next: nodes[idx + 1])
      end
      nil
    end

    # Q: should we support rstrip in addition to strip?
    # TODO add escaping of closing square bracket
    def compose_text el, opts = {}
      strip = opts.delete :strip
      split = opts.delete :split
      wrap = (opts.delete :wrap) || :preserve
      # Q: do we want to merge or just start fresh?
      traverse el, (opts.merge writer: (span_writer = Writer.new))
      # NOTE there should only ever be one line
      text = span_writer.body.join LF
      text = text.strip if strip
      text = reflow text, wrap
      split ? (text.split LF) : text
    end

    def reflow str, wrap
      #return str if str.empty?
      case wrap
      when :ventilate
        unwrap str, true
      when :none
        unwrap str
      else # :preserve
        str
      end
    end

    # NOTE this method requires contiguous non-blank lines
    def unwrap str, ventilate = false
      result = []
      start_new_line = true
      lines = str.split LF
      while (line = lines.shift)
        if line.start_with? '//'
          result << line
          start_new_line = true
        elsif start_new_line
          result << line
          start_new_line = false
        else
          result << %(#{result.pop} #{line})
        end
      end
      if ventilate
        result.map {|line|
          (line.start_with? '//') || !(PUNCTUATION.any? {|punc| line.include? punc }) ? line : (line.gsub FullStopRx, LF)
        }.join LF
      else
        result.join LF
      end
    end
  end
end; end

Kramdown::Converter::Asciidoc = Kramdown::AsciiDoc::Converter
