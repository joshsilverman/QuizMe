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
    @classifier.classify_all
  end

  task :retrain => :environment do
    # classifier is hitting good numbers - retraining has been disabled

    # @classifier = Classifier.new
    # @classifier.train
    # @classifier.classify_all
  end
end