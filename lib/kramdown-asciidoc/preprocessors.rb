module Kramdown; module AsciiDoc
  module Preprocessors
    # Skims off the front matter from the top of the Markdown source and store the data in the provided attributes Hash.
    #
    # @param source [String] the Markdown source from which to extract the front matter.
    # @param attributes [Hash] the attributes in which to store the key/value pairs from the front matter.
    #
    # @return [String] the Markdown source with the front matter removed.
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

    # Replaces the Markdown TOC, if found, with the AsciiDoc toc macro and set the toc attribute to macro.
    #
    # @param source [String] the Markdown source in which the TOC should be replaced.
    # @param attributes [Hash] a map of AsciiDoc attributes to set on the output document.
    #
    # @return [String] the Markdown source with the TOC replaced, if found.
    def self.replace_toc source, attributes
      if source.include? TocDirectiveTip
        attributes['toc'] = 'macro'
        source.gsub TocDirectiveRx, 'toc::[]'
      else
        source
      end
    end

    # Snaps the leading XML comment to the start of the Markdown source.
    #
    # @param markdown [String] the Markdown source to process.
    # @param attributes [Hash] a map of AsciiDoc attributes to set on the output document.
    #
    # @return [String] the Markdown source with whitespace the precedes a leading XML comment removed.
    def self.snap_leading_comment markdown, attributes
      (markdown.start_with? ' ', TAB) && (markdown.lstrip.start_with? '<!--') ? markdown.lstrip : markdown
    end

    private

    TAB = ?\t

    TocDirectiveTip = '<!-- TOC '

    TocDirectiveRx = /^<!-- TOC .*<!-- \/TOC -->/m
  end
end; end
