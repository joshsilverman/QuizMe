require "rake/testtask"

Rake::TestTask.new(:test => "db:test:prepare") do |t|
  t.libs << "test"
  t.libs << "test/minitest"
  t.pattern = "test/minitest/**/*_test.rb"
end

task :default => :test