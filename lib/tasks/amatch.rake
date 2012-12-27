namespace :amatch do

  task :test => :environment do

    matchkit =  Matchkit.new
    matchkit.test
  end
end