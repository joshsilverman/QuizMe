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

  task :retrain => :environment do
    @classifier = Classifier.new
    @classifier.train
    @classifier.classify_all
  end

  task :test_vectors => :environment do
    results = []
    [{:interaction_type => false, :twi_screen_name => false, :previous_spam => false, :previous_real => false},
      {:interaction_type => true, :twi_screen_name => false, :previous_spam => false, :previous_real => false},
      {:interaction_type => true, :twi_screen_name => true, :previous_spam => false, :previous_real => false},
      {:interaction_type => true, :twi_screen_name => true, :previous_spam => true, :previous_real => false},
      {:interaction_type => true, :twi_screen_name => true, :previous_spam => true, :previous_real => true}].each do |opts|

      @classifier = Classifier.new 200000, opts
      @classifier.train
      out = @classifier.classify_all

      results << {:opts => opts, :out => out}
    end

    results.each do |result|
      puts " "
      puts result[:opts]
      puts result[:out]
    end
  end
end