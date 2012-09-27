require 'stuff-classifier'
#require 'Classifier'

namespace :spam_filter do

  task :classify_all => :environment do
    @classifier = Classifier.new
    @classifier.classify_all
  end

  task :build_truthset => :environment do
    @classifier = Classifier.new
    @classifier.build_truthset
  end

  task :retrain => :environment do
    @classifier = Classifier.new
    @classifier.train
    @classifier.classify_all
  end
end