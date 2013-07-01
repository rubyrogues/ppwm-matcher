require './app'
require 'sinatra/activerecord/rake'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
  puts "We don't have rspec"
end

namespace :db do
  desc "Populate the database with example data"
  task :seed do
    10.times do
      code = PpwmMatcher::Code.new
      code.value = code.generate_string
      code.save!
    end
    puts "Generated 10 random codes"
  end
end
