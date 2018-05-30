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

  def self.replace_toc source, attributes
    if source.include? TocDirectiveTip
      attributes['toc'] = 'macro'
      source.gsub TocDirectiveRx, 'toc::[]'
    else
      source
    end
  end

  def self.extract_front_matter source, attributes
    if (line_i = (lines = source.each_line).next) && line_i.chomp == '---'
      lines = lines.drop 1
      front_matter = []
      while (line = lines.shift) && line.chomp != '---'
        front_matter << line
      end
      lines.shift while (line = lines[0]) && line == ?\n
      (::YAML.load front_matter.join).each do |key, val|
        case key
        when 'title'
          # skip
        when 'layout'
          attributes['page-layout'] = val unless val == 'default'
        else
          attributes[key] = val.to_s
        end
      end
      lines.join
    else
      source
    end
  end

  class Converter < ::Kramdown::Converter::Base
    RESOLVE_ENTITY_TABLE = { 60 => '<', 62 => '>', 124 => '|' }
    ADMON_LABELS = %w(Note Tip Caution Warning Important Attention).map {|l| [l, l] }.to_h
    ADMON_MARKERS = ADMON_LABELS.map {|l, _| %(#{l}: ) }
    ADMON_FORMATTED_MARKERS = ADMON_LABELS.map {|l, _| [%(#{l}:), l] }.to_h
    ADMON_TYPE_MAP = ADMON_LABELS.map {|l, _| [l, l.upcase] }.to_h.merge 'Attention' => 'IMPORTANT'
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

    ApostropheRx = /\b’\b/
    CommentPrefixRx = /^ *! ?/m
    CssPropDelimRx = /\s*;\s*/
    ReplaceableTextRx = /[-=]>|<[-=]|\.\.\./
    StartOfLinesRx = /^/m
    TypographicSymbolRx = /[“”‘’—–…]/
    XmlCommentRx = /\A<!--(.*)-->\Z/m

    VoidElement = Element.new nil

    LF = ?\n
    LFx2 = LF * 2

    def initialize root, opts
      super
      @header = []
      @attributes = opts[:attributes] || {}
      @imagesdir = (@attributes.delete 'implicit-imagesdir') || @attributes['imagesdir']
      @last_heading_level = nil
    end

    def convert el, opts = {}
      send %(convert_#{el.type}), el, opts
    end

    def convert_root el, opts
      el = extract_prologue el, opts
      body = %(#{inner el, (opts.merge rstrip: true)}#{LF})
      @attributes.each {|k, v| @header << %(:#{k}: #{v}) } unless @attributes.empty?
      @header.empty? ? body : %(#{@header.join LF}#{body == LF ? '' : LFx2}#{body})
    end

    def convert_blank el, opts
      nil
    end

    def convert_heading el, opts
      result = []
      style = []
      level = el.options[:level]
      if (discrete = @last_heading_level && level > @last_heading_level + 1)
        # TODO make block title promotion an option (allow certain levels and titles)
        #if ((raw_text = el.options[:raw_text]) == 'Example' || raw_text == 'Examples') &&
        if level == 5 && (next_2_siblings = (siblings = opts[:parent].children).slice (siblings.index el) + 1, 2) &&
            next_2_siblings.any? {|sibling| sibling.type == :codeblock }
          return %(.#{inner el, opts}#{LF})
        end
        style << 'discrete'
      end
      if (id = el.attr['id'])
        style << %(##{id})
      elsif (child_i = el.children[0] || VoidElement).type == :html_element && child_i.value == 'a' && (id = child_i.attr['id'])
        el = clone el, children: child_i.children + (el.children.drop 1)
        style << %(##{id})
      elsif (role = el.attr['class'])
        style << %(.#{role.tr ' ', '.'})
      end
      result << %([#{style.join}]) unless style.empty?
      result << %(#{'=' * level} #{inner el, opts})
      @last_heading_level = level unless discrete
      if level == 1 && opts[:result].empty?
        @header += result
        nil
      else
        @attributes['doctype'] = 'book' if level == 1
        %(#{result.join LF}#{LFx2})
      end
    end

    # Kramdown incorrectly uses the term header for headings
    alias convert_header convert_heading

    def convert_p el, opts
      if (parent = opts[:parent]) && parent.type == :li
        # NOTE :prev option not set indicates primary text; convert_li appends LF
        return inner el, opts unless opts[:prev]
        parent.options[:compound] = true
        opts[:result].pop unless opts[:result][-1]
        prefix, suffix = %(#{LF}+#{LF}), ''
      else
        prefix, suffix = '', LFx2
      end
      # NOTE detect plain admonition marker (e.g, Note: ...)
      if (child_i = el.children[0] || VoidElement).type == :text && (child_i_text = child_i.value).start_with?(*ADMON_MARKERS)
        marker, child_i_text = child_i_text.split ': ', 2
        child_i = clone child_i, value: %(#{ADMON_TYPE_MAP[marker]}: #{child_i_text})
        el = clone el, children: [child_i] + (el.children.drop 1)
        contents = inner el, opts
      # NOTE detect formatted admonition marker (e.g., *Note:* ...)
      elsif (child_i.type == :strong || child_i.type == :em) &&
          (marker_el = child_i.children[0]) && ((marker = ADMON_FORMATTED_MARKERS[marker_el.value]) ||
          ((marker = ADMON_LABELS[marker_el.value]) && (child_ii = el.children[1] || VoidElement).type == :text &&
          ((child_ii_text = child_ii.value).start_with? ': ')))
        el = clone el, children: (el.children.drop 1)
        el.children[0] = clone child_ii, value: (child_ii_text.slice 1, child_ii_text.length) if child_ii
        contents = %(#{ADMON_TYPE_MAP[marker]}:#{inner el, opts})
      else
        contents = inner el, opts
      end
      %(#{prefix}#{contents}#{suffix})
    end

    # TODO detect admonition masquerading as blockquote
    def convert_blockquote el, opts
      result = []
      # TODO support more than one level of nesting
      boundary = (parent = opts[:parent]) && parent.type == :blockquote ? '______' : '____'
      contents = inner el, (opts.merge rstrip: true)
      if (contents.include? LF) && ((attribution_line = (lines = contents.split LF).pop).start_with? '-- ')
        attribution = attribution_line.slice 3, attribution_line.length
        result << %([,#{attribution}])
        lines.pop while lines.size > 0 && lines[-1].empty?
        contents = lines.join LF
      end
      result << boundary
      result << contents
      result << boundary
      %(#{result.join LF}#{LFx2})
    end

    def convert_codeblock el, opts
      result = []
      if (parent = opts[:parent]) && parent.type == :li
        parent.options[:compound] = true
        if (current_line = opts[:result].pop)
          opts[:result] << current_line.chomp
        end unless opts[:result].empty?
        list_continuation = %(#{LF}+)
        suffix = ''
      else
        suffix = LFx2
      end
      contents = el.value.rstrip
      if (lang = el.attr['class'])
        lang = lang.slice 9, lang.length if lang.start_with? 'language-'
        # TODO remap lang if requested
        result << %([source,#{lang}])
      end
      if !lang && (contents.start_with? '$ ')
        # QUESTION should we make these a source,console block?
        if contents.include? LFx2
          result << '....'
          result << contents
          result << '....'
        else
          list_continuation = LF if list_continuation
          result << (contents.gsub StartOfLinesRx, ' ')
        end
      else
        result << '----'
        result << contents
        result << '----'
      end
      result.unshift list_continuation if list_continuation
      %(#{result.join LF}#{suffix})
    end

    def convert_ul el, opts
      # TODO create do_in_level block
      level = opts[:level] ? (opts[:level] += 1) : (opts[:level] = 1)
      # REVIEW this is whack
      prefix = (parent = opts[:parent]) && parent.type == :li && !opts[:result][-1] ? LF : ''
      contents = inner el, (opts.merge rstrip: true)
      if level == 1
        suffix = LFx2
        opts.delete :level
      else
        suffix = LF
        opts[:level] -= 1
      end
      %(#{prefix}#{contents}#{suffix})
    end

    alias convert_ol convert_ul

    def convert_li el, opts
      prefix = (prev = opts[:prev]) && prev.options[:compound] ? LF : ''
      marker = opts[:parent].type == :ol ? '.' : '*'
      indent = (level = opts[:level]) - 1
      %(#{prefix}#{indent > 0 ? (' ' * indent) : ''}#{marker * level} #{(inner el, (opts.merge rstrip: true))}#{LF})
    end

    def convert_table el, opts
      head = nil
      cols = (alignments = el.options[:alignment]).size
      if alignments.any? {|align| align == :center || align == :right }
        colspecs = alignments.map {|align| TABLE_ALIGNMENTS[align] }.join ','
        colspecs = %("#{colspecs}") if cols > 1
      end
      table_buf = ['|===']
      el.children.each do |container|
        container.children.each do |row|
          row_buf = []
          row.children.each do |cell|
            cell_contents = inner cell, opts
            cell_contents = cell_contents.gsub '|', '\|' if cell_contents.include? '|'
            row_buf << %(| #{cell_contents})
          end
          if container.type == :thead
            head = true
            row_buf = [row_buf * ' ', '']
          elsif cols > 1
            row_buf << ''
          end
          table_buf.concat row_buf
        end
      end
      if colspecs
        table_buf.unshift %([cols=#{colspecs}])
      elsif !head && cols > 1
        table_buf.unshift %([cols=#{cols}*])
      end
      table_buf.pop if table_buf[-1] == ''
      table_buf << '|==='
      %(#{table_buf * LF}#{LFx2})
    end

    def convert_hr el, opts
      %('''#{LFx2})
    end

    def convert_text el, opts
      if (text = el.value).include? '++'
        @attributes['pp'] = '{plus}{plus}'
        text = text.gsub '++', '{pp}'
      end
      text = text.gsub '^', '{caret}' if (text.include? '^') && text != '^'
      text = text.gsub '<=', '\<=' if text.include? '<='
      if text.ascii_only?
        text
      else
        (text.gsub ApostropheRx, ?').gsub TypographicSymbolRx, TYPOGRAPHIC_SYMBOL_TO_MARKUP
      end
    end

    def convert_codespan el, opts
      (val = el.value) =~ ReplaceableTextRx ? %(`+#{val}+`) : %(`#{val}`)
    end

    def convert_em el, opts
      %(_#{inner el, opts}_)
    end

    def convert_strong el, opts
      %(*#{inner el, opts}*)
    end

    # NOTE this logic assumes the :hard_wrap option is disabled in the parser
    def convert_br el, opts
      prefix = ((opts[:result][-1] || '').end_with? ' ') ? '' : ' '
      # if @attr is set, this is a <br> HTML tag
      if el.instance_variable_get :@attr
        siblings = opts[:parent].children
        suffix = (next_el = siblings[(siblings.index el) + 1] || VoidElement).type == :text && (next_el.value.start_with? LF) ? '' : LF
      else
        suffix = ''
      end
      %(#{prefix}+#{suffix})
    end

    def convert_smart_quote el, opts
      SMART_QUOTE_ENTITY_TO_MARKUP[el.value]
    end

    def convert_entity el, opts
      RESOLVE_ENTITY_TABLE[el.value.code_point] || el.options[:original]
    end

    def convert_a el, opts
      if (url = el.attr['href']).start_with? '#'
        %(<<#{url.slice 1, url.length},#{inner el, opts}>>)
      elsif url.start_with? 'https://', 'http://'
        if (children = el.children).size == 1 && (child_i = el.children[0]).type == :img
          convert_img child_i, parent: opts[:parent], index: 0, url: url
        else
          bare = ((contents = inner el, opts).chomp '/') == (url.chomp '/')
          url = url.gsub '__', '%5F%5F' if (url.include? '__')
          bare ? url : %(#{url}[#{contents.gsub ']', '\]'}])
        end
      elsif url.end_with? '.md'
        %(xref:#{url.slice 0, url.length - 3}.adoc[#{(inner el, opts).gsub ']', '\]'}])
      else
        %(link:#{url}[#{(inner el, opts).gsub ']', '\]'}])
      end
    end 

    def convert_img el, opts
      if !(parent = opts[:parent]) || parent.type == :p && parent.children.size == 1
        style = []
        if (id = el.attr['id'])
          style << %(##{id})
        end
        if (role = el.attr['class'])
          style << %(.#{role.tr ' ', '.'})
        end
        macro_prefix = style.empty? ? 'image::' : ([%([#{style.join}]), 'image::'].join LF)
      else
        macro_prefix = 'image:'
      end
      macro_attrs = []
      if (alt_text = el.attr['alt'])
        macro_attrs << alt_text unless alt_text.empty?
      end
      if (width = el.attr['width'])
        macro_attrs << '' if macro_attrs.empty?
        macro_attrs << width
      elsif (css = el.attr['style']) && (width_css = (css.split CssPropDelimRx).find {|p| p.start_with? 'width:' })
        macro_attrs << '' if macro_attrs.empty?
        width = (width_css.slice (width_css.index ':') + 1, width_css.length).strip
        unless width.end_with? '%'
          width = width.to_f
          width = width.to_i if width == width.to_i
        end
        macro_attrs << width
      end
      if (url = opts[:url])
        macro_attrs << %(link=#{url})
      end
      src = el.attr['src']
      if (imagesdir = @imagesdir) && (src.start_with? %(#{imagesdir}/))
        src = src.slice imagesdir.length + 1, src.length
      end
      %(#{macro_prefix}#{src}[#{macro_attrs.join ','}])
    end

    # NOTE leave enabled so we can down-convert mdash to --
    def convert_typographic_sym el, opts
      TYPOGRAPHIC_ENTITY_TO_MARKUP[el.value]
    end

    def convert_html_element el, opts
      if (tagname = el.value) == 'div' && (child_i = el.children[0]) && child_i.options[:transparent] &&
          (child_i_i = child_i.children[0])
        if child_i_i.type == :img
          return convert_img child_i_i, (opts.merge parent: child_i, index: 0) if child_i.children.size == 1
        elsif child_i_i.value == 'span' && ((role = el.attr['class'] || '').start_with? 'note') &&
            child_i_i.attr['class'] == 'notetitle'
          marker = ADMON_FORMATTED_MARKERS[(child_i_i.children[0] || VoidElement).value] || 'Note'
          (el = child_i.dup).children = el.children.drop 1
          return %(#{ADMON_TYPE_MAP[marker]}:#{inner el, opts}#{LFx2})
        end
      end
      contents = inner el, (opts.merge rstrip: el.options[:category] == :block)
      attrs = (attrs = el.attr).empty? ? '' : attrs.map {|k, v| %( #{k}="#{v}") }.join
      case tagname
      when 'sup'
        %(^#{contents}^)
      when 'sub'
        %(~#{contents}~)
      else
        %(+++<#{tagname}#{attrs}>+++#{contents}+++</#{tagname}>+++)
      end
    end

    def convert_xml_comment el, opts
      XmlCommentRx =~ el.value
      comment_text = ($1.include? ' !') ? ($1.gsub CommentPrefixRx, '').strip : $1.strip
      #siblings = (parent = opts[:parent]) ? parent.children : []
      if (el.options[:category] == :block)# || (!opts[:result][-1] && siblings[-1] == el)
        if comment_text.empty?
          %(//-#{LFx2})
        elsif comment_text.include? LF
          %(////#{LF}#{comment_text}#{LF}////#{LFx2})
        else
          %(// #{comment_text}#{LFx2})
        end
      else
        if (current_line = opts[:result][-1])
          if current_line.end_with? LF
            prefix = ''
          else
            prefix = LF
            opts[:result][-1] = (current_line = current_line.rstrip) if current_line.end_with? ' '
          end
        else
          prefix = ''
        end
        siblings = (parent = opts[:parent]) && parent.children
        suffix = siblings && siblings[(siblings.index el) + 1] ? LF : ''
        if comment_text.include? LF
          %(#{prefix}#{comment_text.gsub StartOfLinesRx, '// '}#{suffix})
        else
          %(#{prefix}// #{comment_text}#{suffix})
        end
      end
    end

    def extract_prologue el, opts
      if (child_i = (children = el.children)[0] || VoidElement).type == :xml_comment
        (prologue_el = el.dup).children = children.take_while {|child| child.type == :xml_comment || child.type == :blank }
        (el = el.dup).children = children.drop prologue_el.children.size
        @header += [%(#{inner prologue_el, (opts.merge rstrip: true)})]
      end
      el
    end

    def inner el, opts = {}
      rstrip = opts.delete :rstrip
      result = []
      prev = nil
      el.children.each_with_index do |child, idx|
        result << (send %(convert_#{child.type}), child, (opts.merge parent: el, index: idx, result: result, prev: prev))
        prev = child
      end
      rstrip ? result.join.rstrip : result.join
    end

    def clone el, properties = {}
      el = el.dup
      properties.each do |name, value|
        el.send %(#{name}=).to_sym, value
      end
      el
    end
  end
end; end

Kramdown::Converter::Asciidoc = Kramdown::AsciiDoc::Converter
