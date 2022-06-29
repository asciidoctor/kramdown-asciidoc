# frozen_string_literal: true

require 'yaml'

autoload :Date, 'time'
autoload :Time, 'time'

unless (YAML.method :safe_load).parameters.include? [:key, :aliases]
  YAML.singleton_class.prepend (Module.new do
    def safe_load yaml, permitted_classes: [], permitted_symbols: [], aliases: false, filename: nil
      super yaml, permitted_classes, permitted_symbols, aliases, filename
    end
  end)
end
