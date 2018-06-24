case ENV['COVERAGE']
when 'deep'
  ENV['DEEP_COVER'] = 'true'
  require 'deep_cover'
when 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
end

require 'kramdown-asciidoc'
require 'fileutils'

RSpec.configure do |config|
  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def output_dir
    dir = File.join __dir__, 'output'
    FileUtils.mkpath dir
    dir
  end

  def output_file relative
    File.join output_dir, relative
  end
end
