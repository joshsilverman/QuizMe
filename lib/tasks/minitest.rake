Rake::TestTask.new(:alltest) do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end