# frozen_string_literal: true

module Kramdown
module AsciiDoc
  module CoreExt
    refine Regexp do
      # rubocop:disable Style/Alias
      alias match? === unless method_defined? :match? # nocov
      # rubocop:enable Style/Alias
    end
  end
end
end
