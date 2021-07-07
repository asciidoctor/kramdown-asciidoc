# frozen_string_literal: true

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new :lint do |t|
    t.patterns = %w(bin/* lib/**/*.rb spec/*.rb Rakefile Gemfile tasks/*.rake)
  end
rescue LoadError => e
  task :lint do
    raise <<~'EOS', cause: e
    Failed to load lint task.
    Install required gems using: bundle --path=.bundle/gems
    Next, invoke Rake using: bundle exec rake
    EOS
  end
end
