require 'stuff-classifier'

namespace :spam_filter do

  task :classify_all => :environment do
    @classifier = Classifier.new
    @classifier.classify_all
  end

  task :classify_testing_set => :environment do
    @classifier = Classifier.new
    @classifier.classify_testing_set
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

  # @classifier = Classifier.new
  # @classifier.classify post
end