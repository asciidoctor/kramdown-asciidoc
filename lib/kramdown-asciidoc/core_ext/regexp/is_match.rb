module Kramdown; module AsciiDoc; module CoreExt
  refine Regexp do
    alias match? === unless method_defined? :match? # nocov
  end
end; end; end
