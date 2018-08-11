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
autoload :StringIO, 'stringio'
autoload :Shellwords, 'shellwords'

RSpec.configure do |config|
  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def output_dir
    dir = File.join __dir__, 'output'
    FileUtils.mkpath dir
    dir
  end

  def output_file path
    File.join output_dir, path
  end

  def scenarios_dir 
    File.join __dir__, 'scenarios'
  end

  def scenario_file path
    File.join scenarios_dir, path
  end

  def ruby
    Shellwords.escape File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
  end
end
