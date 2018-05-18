module Kramdown
  module Converter
    # IMPORTANT This class is named Asciidoc instead of AsciiDoc so the converter name is "asciidoc"
    class Asciidoc < Base
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
          inner el, opts
        elsif (first_child = el.children[0]).type == :text && ((val = first_child.value).start_with? 'Note: ')
          first_child.value = %(NOTE: #{val.slice 6, val.length})
          %(#{inner el, opts}#{LFx2})
        # TODO detect when colon is outside of formatted text
        elsif (first_child.type == :strong || first_child.type == :em) &&
            (label_el = first_child.children[0]) && label_el.value == 'Note:'
          el.children.shift
          %(NOTE:#{inner el, opts}#{LFx2})
        else
          %(#{inner el, opts}#{LFx2})
        end
      end

      # TODO detect admonition masquerading as blockquote
      def convert_blockquote el, opts
        result = []
        result << '____'
        result << (inner el, (opts.merge rstrip: true))
        result << '____'
        %(#{result.join LF}#{LFx2})
      end

      def convert_codeblock el, opts
        result = []
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
            result << (code.gsub %r/^/m, ' ')
          end
        else
          result << '----'
          result << code
          result << '----'
        end
        %(#{result.join LF}#{LFx2})
      end

      def convert_ul el, opts
        # TODO create do_in_level block
        level = if opts.key? :level
          opts[:level] += 1
        else
          opts[:level] = 1
        end
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
        marker = opts[:parent].type == :ol ? '.' : '*'
        %(#{marker * opts[:level]} #{(inner el, (opts.merge rstrip: true))}#{LF})
      end

      def convert_table el, opts
        table_buf = ['|===']
        el.children.each do |container|
          container.children.each do |row|
            row_buf = []
            row.children.each do |cell|
              row_buf << %(|#{inner cell, opts})
            end
            row_buf = [(row_buf * ' ')] if container.type == :thead
            row_buf << ''
            table_buf.concat row_buf
          end
        end
        table_buf.pop if table_buf.last == ''
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

      # QUESTION how can we detect a markdown-style hard wrap?
      def convert_br el, opts
        #' +'
        nil
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
        # FIXME constantify map
        symbol_map = {
          lt: '<',
          gt: '>'
        }
        symbol_map[el.value]
      end

      def convert_a el, opts
        if (url = el.attr['href']).start_with? '#'
          %(<<_#{url[1..-1]},#{inner el, opts}>>)
        elsif url =~ /^https?:\/\//
          (label = inner el, opts) == url ? (url.chomp '/') : %(#{url.chomp '/'}[#{label}])
        else
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
          mdash: '--',
          ndash: '-',
          hellip: '...',
          laquo: '<<',
          raquo: '>>',
          laquo_scape: '<< ',
          raquo_space: ' >>'
        }
        symbol_map[el.value]
      end

      def convert_html_element el, opts
        # QUESTION isn't this unnecessary now that we set html_to_native option?
        if (tagname = el.value) == 'pre'
          # TODO create helper to strip surrounding endlines
          %(....#{LF}#{(inner el, opts).gsub(/\A\n*(.*?)\n*\Z/m, '\1')}#{LF}....#{LFx2})
        else
          %(+++<#{tagname}>#{inner el, opts}</#{tagname}>+++)
        end
      end

      def inner el, opts
        rstrip = opts.delete :rstrip
        result = []
        child_opts = opts.merge parent: el
        prev = nil
        el.children.each_with_index do |child, idx|
          options[:index] = idx
          options[:result] = result
          options[:prev] = prev if prev
          result << (send %(convert_#{child.type}), child, child_opts)
          prev = child
        end
        rstrip ? result.join.rstrip : result.join
      end
    end
  end
end
