module Kramdown; module Converter
  class AsciiDoc < Base
    DEFAULT_PARSER_OPTS = { auto_ids: false, html_to_native: true, input: 'GFM' }
    RESOLVE_ENTITY_TABLE = %w(lt gt).map {|name| Utils::Entities.entity name }.map {|obj| [obj, obj.char] }.to_h

    XmlCommentRx = /\A<!--(.*)-->\Z/m
    CommentPrefixRx = /^ *! ?/m

    LF = %(\n)
    LFx2 = %(\n\n)

    #def initialize root, opts
    #  super
    #end

    def convert el, opts = {}
      send %(convert_#{el.type}), el, opts
    end

    def convert_root el, opts
      (inner el, (opts.merge rstrip: true))
    end

    def convert_blank el, opts
      nil
    end

    def convert_heading el, opts
      result = []
      if (first_child = el.children[0]) && first_child.type == :html_element &&
          first_child.value == 'a' && (id = first_child.attr['id'])
        result << %([##{id}])
      end
      # FIXME preserve inline markup
      result << %(#{'=' * (level = el.options[:level])} #{el.options[:raw_text]})
      #result << ':pp: {plus}{plus}' if level == 1 && opts[:index] == 0
      %(#{result.join LF}#{LFx2})
    end

    # Kramdown incorrectly uses the term header for headings
    alias convert_header convert_heading

    def convert_p el, opts
      if (parent = opts[:parent]) && parent.type == :li
        if opts[:prev]
          parent.options[:compound] = true
          opts[:result].pop
          %(#{LF}+#{LF}#{inner el, opts})
        else
          inner el, opts
        end
      elsif (first_child = el.children[0]).type == :text && ((val = first_child.value).start_with? 'Note: ')
        first_child.value = %(NOTE: #{val.slice 6, val.length})
        %(#{inner el, opts}#{LFx2})
      # NOTE detect *Note:* or **Note:** or *Note*: or **Note**: prefix
      elsif (first_child.type == :strong || first_child.type == :em) &&
          (label_el = first_child.children[0]) && (label_el.value == 'Note:' ||
          (label_el.value == 'Note' && (second_child = el.children[1]) && second_child.type == :text &&
          ((text = second_child.value).start_with? ': ')))
        el.children.shift
        second_child.value = text.slice 1, text.length if second_child
        %(NOTE:#{inner el, opts}#{LFx2})
      else
        %(#{inner el, opts}#{LFx2})
      end
    end

    # TODO detect admonition masquerading as blockquote
    def convert_blockquote el, opts
      result = []
      # TODO support more than one level of nesting
      boundary = (parent = opts[:parent]) && parent.type == :blockquote ? '______' : '____'
      contents = inner el, (opts.merge rstrip: true)
      if (contents.include? LF) && ((attribution_line = (lines = contents.split LF).pop).start_with? '&#8211; ')
        attribution = attribution_line.slice 8, attribution_line.length
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
        opts[:result].pop
        list_continuation = %(#{LF}+)
        suffix = ''
      else
        suffix = LFx2
      end
      if (lang = el.attr['class'])
        lang = lang.slice 9, lang.length if lang.start_with? 'language-'
        result << %([source,#{lang}])
      end
      # QUESTION should we rstrip?
      code = el.value.chomp
      if !lang && (code.start_with? '$')
        if code.include? LFx2
          result << '....'
          result << code
          result << '....'
        else
          list_continuation = LF if list_continuation
          # FIXME promote regex to const
          result << (code.gsub %r/^/m, ' ')
        end
      else
        result << '----'
        result << code
        result << '----'
      end
      result.unshift list_continuation if list_continuation
      %(#{result.join LF}#{suffix})
    end

    def convert_ul el, opts
      # TODO create do_in_level block
      level = (opts.key? :level) ? (opts[:level] += 1) : (opts[:level] = 1)
      buf = %(#{(inner el, (opts.merge rstrip: true))}#{LF})
      if level == 1
        buf = %(#{buf}#{LF})
        opts.delete :level
      else
        opts[:level] -= 1
      end
      buf
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
      result = el.value
      #result = result.gsub '++', '{pp}' if result.include? '++'
      if result.ascii_only?
        result
      else
        # FIXME extract this mapping
        mapping = { '“' => '"`', '”' => '`"', '‘' => '\'`', '’' => '`\'', '–' => '--', '…' => '...' }
        result.gsub(/\b’\b/, '\'').gsub(/[“”‘’–…]/, mapping)
      end
    end

    def convert_codespan el, opts
      # FIXME constantify regex
      (val = el.value) =~ /(?:[-=]>|<[-=]|\.\.\.)/ ? %(`+#{val}+`) : %(`#{val}`)
    end

    def convert_em el, opts
      %(_#{inner el, opts}_)
    end

    def convert_strong el, opts
      %(*#{inner el, opts}*)
    end

    def convert_br el, opts
      # handle <br/>
      if el.instance_variable_get :@attr
        spacer = (last_result = opts[:result][-1]) && (last_result.end_with? ' ') ? '' : ' '
        %(#{spacer}+#{LF})
      else
        # TODO detect a markdown-style hard wrap by looking for two spaces at end of previous element
        nil
      end
    end

    def convert_smart_quote el, opts
      # FIXME constantify map
      symbol_map = {
        ldquo: '"',
        rdquo: '"',
        lsquo: '\'',
        rsquo: '\''
      }
      symbol_map[el.value]
    end

    def convert_entity el, opts
      RESOLVE_ENTITY_TABLE[el.value] || el.options[:original]
    end

    def convert_a el, opts
      if (url = el.attr['href']).start_with? '#'
        %(<<#{url.slice 1, url.length},#{inner el, opts}>>)
      # FIXME promote regex to const
      elsif url =~ /^https?:\/\//
        (label = inner el, opts) == url ? (url.chomp '/') : %(#{url.chomp '/'}[#{label}])
      else
        # QUESTION should we replace .md suffix with .adoc?
        %(link:#{url}[#{inner el, opts}])
      end
    end 

    def convert_img el, opts
      prefix = !(parent = opts[:parent]) || parent.children.size == 1 ? 'image::' : 'image:'
      # TODO detect case when link is wrapped around image
      %(#{prefix}#{el.attr['src']}[#{el.attr['alt']}])
    end

    def convert_typographic_sym el, opts
      # FIXME constantify map
      symbol_map = {
        # FIXME in the future, mdash will be three dashes and ndash two
        mdash: '--',
        ndash: '&#8211;',
        hellip: '...',
        laquo: '<<',
        raquo: '>>',
        laquo_scape: '<< ',
        raquo_space: ' >>'
      }
      symbol_map[el.value]
    end

    def convert_html_element el, opts
      contents = inner el, (opts.merge rstrip: true)
      case (tagname = el.value)
      when 'sup'
        %(^#{contents}^)
      when 'sub'
        %(~#{contents}~)
      else
        %(+++<#{tagname}>+++#{contents}+++</#{tagname}>+++)
      end
    end

    def convert_xml_comment el, opts
      XmlCommentRx =~ el.value
      comment_text = ($1.include? ' !') ? ($1.gsub CommentPrefixRx, '').strip : $1.strip
      if el.options[:category] == :block
        if comment_text.empty?
          %(//-#{LFx2})
        elsif comment_text.include? LF
          #%(#{$1.split(LF).map {|l| %[// #{l}] }.join LF}#{LFx2})
          %(////#{LF}#{comment_text}#{LF}////#{LFx2})
        else
          %(// #{comment_text}#{LFx2})
        end
      else
        if (current_line = opts[:result][-1])
          if current_line == LF
            prefix = ''
          else
            prefix = LF
            opts[:result][-1] = (current_line = current_line.rstrip) if current_line.end_with? ' '
          end
        else
          prefix = ''
        end
        siblings = opts[:parent].children
        suffix = siblings[(siblings.index el) + 1] ? LF : ''
        %(#{prefix}// #{comment_text}#{suffix})
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
  end

  # IMPORTANT Must add Asciidoc as alias so converter name becomes "asciidoc"
  Asciidoc = AsciiDoc
end; end
