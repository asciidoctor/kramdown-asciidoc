module Kramdown
  module Converter
    # IMPORTANT This class is named Asciidoc instead of AsciiDoc so the converter name is "asciidoc"
    class Asciidoc < Base
      def initialize root, opts
        super
      end

      def convert el, opts = {}
        send %(convert_#{el.type}), el, opts
      end

      def inner el, opts
        result = []
        options = opts.merge parent: el
        prev = nil
        el.children.each_with_index do |inner_el, idx|
          options[:index] = idx
          options[:result] = result
          options[:prev] = prev
          result << (send %(convert_#{inner_el.type}), inner_el, options)
          prev = inner_el
        end
        result.join
      end

      def convert_root el, opts
        # QUESTION can we add rstrip to inner?
        (inner el, opts).rstrip
      end

      def convert_blank el, opts
        #"\n\n"
        nil
      end

      def convert_header el, opts
        level = el.options[:level]
        #endlines = level > 1 ? "\n\n" : nil
        endlines = "\n\n"
        %(#{'=' * level} #{el.options[:raw_text]}#{endlines})
      end

      def convert_text el, opts
        el.value 
      end

      def convert_em el, opts
        %(_#{inner el, opts}_)
      end

      def convert_strong el, opts
        %(*#{inner el, opts}*)
      end

      def convert_p el, opts
        endlines = opts[:parent].type == :li ? nil : "\n\n"
        %(#{inner el, opts}#{endlines})
      end

      def convert_codeblock el, opts
        result = []
        if (lang = el.attr['class'])
          lang = lang.sub(/^language-/, '')
          result << %([source,#{lang}])
        end
        code = el.value.chomp
        if lang || !(code.start_with? '$')
          result << '----'
          result << code
          result << '----'
        else
          result << code.gsub(/^/m, ' ')
        end
        %(#{result * "\n"}\n\n)
      end

      def convert_ul el, opts
        # TODO create do_in_level block
        level = if opts.key? :level
          opts[:level] += 1
        else
          opts[:level] = 1
        end
        buf = %(#{(inner el, opts).rstrip}\n)
        if level == 1
          buf = %(#{buf}\n)
          opts.delete :level
        else
          opts[:level] -= 1
        end
        buf
      end

      alias :convert_ol :convert_ul
      #def convert_ol el, opts
      #  %(#{(inner el, opts).chomp "\n\n"})
      #end

      def convert_li el, opts
        marker = opts[:parent].type == :ol ? '.' : '*'
        %(#{marker * opts[:level]} #{(inner el, opts).rstrip}\n)
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
        %(#{table_buf * "\n"}\n\n)
      end

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

      def convert_html_element el, opts
        if (tagname = el.value) == 'pre'
          # TODO create helper to strip surrounding endlines
          %(....\n#{(inner el, opts).gsub(/\A\n*(.*?)\n*\Z/m, '\1')}\n....\n\n)
        else
          %(+++<#{tagname}>#{inner el, opts}</#{tagname}>+++)
        end
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

      def convert_codespan el, opts
        # FIXME constantify regex
        (val = el.value) =~ /(?:[-=]>|<[-=]|\.\.\.)/ ? %(`+#{val}+`) : %(`#{val}`)
      end

      def convert_img el, opts
        # TODO detect case when link is wrapped around image
        %(image:#{el.attr['src']}[#{el.attr['alt']}])
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
    end
  end
end
