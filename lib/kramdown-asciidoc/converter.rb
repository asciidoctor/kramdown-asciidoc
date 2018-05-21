# encoding: UTF-8
module Kramdown; module Converter
  class AsciiDoc < Base
    DEFAULT_PARSER_OPTS = { auto_ids: false, hard_wrap: false, html_to_native: true, input: 'GFM' }
    RESOLVE_ENTITY_TABLE = %w(lt gt).map {|name| Utils::Entities.entity name }.map {|obj| [obj, obj.char] }.to_h
    ADMON_LABELS = %w(Note Tip Caution Warning Important Attention).map {|l| [l, l] }.to_h
    ADMON_MARKERS = ADMON_LABELS.map {|l, _| %(#{l}: ) }
    ADMON_FORMATTED_MARKERS = ADMON_LABELS.map {|l, _| [%(#{l}:), l] }.to_h
    ADMON_TYPE_MAP = ADMON_LABELS.map {|l, _| [l, l.upcase] }.to_h.merge 'Attention' => 'IMPORTANT'
    # FIXME here we reverse the smart quotes; add option to allow them (needs to be handled carefully)
    SMART_QUOTE_ENTITY_TO_MARKUP = { ldquo: '"', rdquo: '"', lsquo: '\'', rsquo: '\'' }
    TYPOGRAPHIC_SYMBOL_TO_MARKUP = {
      '“' => '"`',
      '”' => '`"',
      '‘' => '\'`',
      '’' => '`\'',
      # FIXME in the future, mdash will be three dashes in AsciiDoc; for now, down-convert
      '—' => '--',
      '–' => '&#8211;',
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

    ApostropheRx = /\b’\b/
    CommentPrefixRx = /^ *! ?/m
    TocDirectiveTip = '<!-- TOC '
    TocDirectiveRx = /^<!-- TOC .*<!-- \/TOC -->/m
    ReplaceableTextRx = /[-=]>|<[-=]|\.\.\./
    StartOfLinesRx = /^/m
    TypographicSymbolRx = /[“”‘’—–…]/
    XmlCommentRx = /\A<!--(.*)-->\Z/m

    VoidElement = Element.new nil

    LF = %(\n)
    LFx2 = %(\n\n)

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
      body = inner el, (opts.merge rstrip: true)
      @attributes.each {|k, v| @header << %(:#{k}: #{v}) } unless @attributes.empty?
      @header.empty? ? body : (body.empty? ? (@header.join LF) : %(#{@header.join LF}#{LFx2}#{body}))
    end

    def convert_blank el, opts
      nil
    end

    def convert_heading el, opts
      result = []
      style = []
      level = el.options[:level]
      style << 'discrete' if (discrete = @last_heading_level && level > @last_heading_level + 1)
      if (id = el.attr['id'])
        style << %(##{id})
      elsif (child_i = el.children[0] || VoidElement).type == :html_element && child_i.value == 'a' && (id = child_i.attr['id'])
        el.children.shift
        el.children.unshift(*child_i.children) unless child_i.children.empty?
        style << %(##{id})
      elsif (role = el.attr['class'])
        style << %(.#{role.tr ' ', '.'})
      end
      result << %([#{style.join}]) unless style.empty?
      result << %(#{'=' * level} #{inner el, opts})
      @last_heading_level = level unless discrete
      if level == 1 && opts[:result].empty?
        @header = result
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
        child_i.value = %(#{ADMON_TYPE_MAP[marker]}: #{child_i_text})
        contents = inner el, opts
      # NOTE detect formatted admonition marker (e.g., *Note:* ...)
      elsif (child_i.type == :strong || child_i.type == :em) &&
          (marker_el = child_i.children[0]) && ((marker = ADMON_FORMATTED_MARKERS[marker_el.value]) ||
          ((marker = ADMON_LABELS[marker_el.value]) && (child_ii = el.children[1] || VoidElement).type == :text &&
          ((child_ii_text = child_ii.value).start_with? ': ')))
        el.children.shift
        child_ii.value = child_ii_text.slice 1, child_ii_text.length if child_ii
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
        #lang = 'console' if lang == 'bash' && (contents.start_with? '$ ')
        lang = 'console' if lang == 'bash'
        result << %([source,#{lang}])
      end
      if !lang && (contents.start_with? '$ ')
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
      head = cols = nil
      table_buf = ['|===']
      el.children.each do |container|
        container.children.each do |row|
          row_buf = []
          row.children.each do |cell|
            row_buf << %(| #{inner cell, opts})
          end
          cols = row_buf.size unless cols
          if container.type == :thead
            head = true
            row_buf = [row_buf * ' ']
          end
          row_buf << ''
          table_buf.concat row_buf
        end
      end
      table_buf.unshift %([cols=#{cols}*]) unless head
      table_buf.pop if table_buf[-1] == ''
      table_buf << '|==='
      %(#{table_buf * LF}#{LFx2})
    end

    def convert_hr el, opts
      %('''#{LFx2})
    end

    def convert_text el, opts
      if (result = el.value).include? '++'
        @attributes['pp'] = '{plus}{plus}'
        result = result.gsub '++', '{pp}'
      end
      if result.ascii_only?
        result
      else
        (result.gsub ApostropheRx, '\'').gsub TypographicSymbolRx, TYPOGRAPHIC_SYMBOL_TO_MARKUP
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
      RESOLVE_ENTITY_TABLE[el.value] || el.options[:original]
    end

    def convert_a el, opts
      if (url = el.attr['href']).start_with? '#'
        %(<<#{url.slice 1, url.length},#{inner el, opts}>>)
      elsif url.start_with? 'https://', 'http://'
        if (child_i = el.children[0] || VoidElement).type == :img
          convert_img child_i, parent: opts[:parent], index: 0, url: url
        else
          ((contents = inner el, opts).chomp '/') == (url.chomp '/') ? url : %(#{url}[#{contents}])
        end
      elsif url.end_with? '.md'
        %(xref:#{url.slice 0, url.length - 3}.adoc[#{inner el, opts}])
      else
        %(link:#{url}[#{inner el, opts}])
      end
    end 

    def convert_img el, opts
      prefix = !(parent = opts[:parent]) || parent.type == :p && parent.children.size == 1 ? 'image::' : 'image:'
      alt_text = el.attr['alt']
      link_attr = (url = opts[:url]) ? %(#{alt_text.empty? ? '' : ','}link=#{url}) : ''
      src = el.attr['src']
      if (imagesdir = @imagesdir) && (src.start_with? %(#{imagesdir}/))
        src = src.slice imagesdir.length + 1, src.length
      end
      %(#{prefix}#{src}[#{alt_text}#{link_attr}])
    end

    # NOTE leave enabled so we can down-convert mdash to --
    def convert_typographic_sym el, opts
      TYPOGRAPHIC_ENTITY_TO_MARKUP[el.value]
    end

    def convert_html_element el, opts
      contents = inner el, (opts.merge rstrip: el.options[:category] == :block)
      attrs = (attrs = el.attr).empty? ? '' : attrs.map {|k, v| %( #{k}="#{v}") }.join
      case (tagname = el.value)
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

    def inner el, opts
      rstrip = opts.delete :rstrip
      result = []
      prev = nil
      el.children.each_with_index do |child, idx|
        result << (send %(convert_#{child.type}), child, (opts.merge parent: el, index: idx, result: result, prev: prev))
        prev = child
      end
      rstrip ? result.join.rstrip : result.join
    end

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
        require 'yaml' unless defined? ::YAML
        lines = lines.drop 1
        front_matter = []
        while (line = lines.shift) && line.chomp != '---'
          front_matter << line
        end
        lines.shift while (line = lines[0]) && line.chomp.empty?
        (YAML.load front_matter.join).each do |key, val|
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
  end

  # IMPORTANT Must add Asciidoc as alias so converter name becomes "asciidoc"
  Asciidoc = AsciiDoc
end; end
