class Classifier
  def initialize
    @store = StuffClassifier::FileStorage.new("#{Rails.root}/vendor/assets/classifiers/stuff-classifier")
    StuffClassifier::Base.storage = @store
    @stuff_classifier = StuffClassifier::Bayes.new("Spam or Real", :storage => @store)
  end

  def build_truthset

    puts <<-EOS

      Building a truthset for the classifier to train and test itself.
      NOTE: THIS WILL ONLY WORK WITH A MUTABLE FILESYSTEM (ie NOT Heroku)

      How many engagements do you want to tag?
    EOS
    input = STDIN.gets.chomp.to_i

    unmarked_posts_by_users[0..input].each_with_index do |post, i|
      puts <<-EOS

        Checking if post #{post.id} is spam:

          #{i + 1}: #{post.text}

        Spam or real (or next)? (s/r/n)
      EOS
      input = STDIN.gets.chomp

      if input == 's'
        post.update_attribute :spam, true
      elsif input == 'r'
        post.update_attribute :spam, false
      end
    end
  end

  def classify_all
    puts <<-EOS

      Running classifier on all posts by users
    EOS
    precision, recall, ci = classify_set posts_by_users
    puts <<-EOS

      Results for whole corpus including truthset:
        Posts by users (excl. RTs):#{posts_by_users.count}
        Truthset:#{marked_posts_by_users.count}
        Training set:#{posts_for_training.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}
    EOS
  end

  def classify_testing_set
    puts <<-EOS

      Running classifier on testing set
    EOS
    precision, recall, ci = classify_set posts_for_testing
    puts <<-EOS

      Results for testing:
        Testing set:#{posts_for_testing.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}
    EOS
  end

  def classify_training_set
    puts <<-EOS

      Running classifier on training set (results should be excellent)
    EOS
    precision, recall, ci = classify_set posts_for_training
    puts <<-EOS

      Results for training:
        Training set:#{posts_for_training.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}
    EOS
  end

  def classify_set posts
    results = {:real => {:correct => 0, :incorrect => 0}, :spam => {:correct => 0, :incorrect => 0}}
    posts.each do |post|
      klass, correct = classify(post)
      results[klass][correct] += 1 if correct != nil
    end

    real_in_truthset = results[:real][:correct] + results[:spam][:incorrect]
    correctly_detected_real_in_truthset = results[:real][:correct]
    detected_real_in_truthset = results[:real][:correct] + results[:real][:incorrect]

    precision = correctly_detected_real_in_truthset.to_f/detected_real_in_truthset if detected_real_in_truthset
    recall = correctly_detected_real_in_truthset.to_f/real_in_truthset if real_in_truthset
    ci = confidence_interval marked_posts_by_users.count, posts_by_users.count, recall

    return precision, recall, ci
  end

  def train

    puts <<-EOS

      Training classifier

      This will purge the current classifier.
      Continue? (y/n)
    EOS
    return false if STDIN.gets.chomp == "n"
    purge_classifier

    puts <<-EOS

      Training classifier on (random, half) subset of truthset.
    EOS

    posts_for_training.each_with_index do |post, i|
      puts <<-EOS

        #{i + 1}: Training post #{post.id} as spam.
      EOS

      if post.spam == true
        @stuff_classifier.train(:spam, post.text)
      elsif post.spam == false
        @stuff_classifier.train(:real, post.text)
      end

      @stuff_classifier.save_state
    end
  end

  #private

  def classify post
    klass = @stuff_classifier.classify(post.text)
    if klass == :spam
      post.update_attribute :autospam, true
    else
      post.update_attribute :autospam, false
    end

    grade = nil
    if post.spam != nil
      grade = :correct if post.spam == post.autospam
      grade = :incorrect if post.spam != post.autospam
    end
    return klass, grade
  end

  def purge_classifier
    @stuff_classifier = StuffClassifier::Bayes.new("Spam or Real", :purge_state => true, :storage => @store)
  end

  def confidence_interval sample_size, population, percentage
    z = 1.96
    sample_size_finite = sample_size.to_f / (1 + ((sample_size-1).to_f/population))
    Math.sqrt((z**2*percentage*(1-percentage))/sample_size_finite)
  end

  def posts_by_users
    @_posts_by_users ||= Post.includes(:user).where('users.role = "user" AND posts.text != ""').order("random()")
    @_posts_by_users
  end

  def unmarked_posts_by_users
    @_unmarked_posts_by_users ||= Post.includes(:user).where('users.role = ? AND spam IS NULL AND posts.text != ""', 'user').order("random()")
    @_unmarked_posts_by_users
  end

  def marked_posts_by_users
    @_marked_posts_by_users ||= Post.includes(:user).where('users.role = ? AND spam IS NOT NULL AND posts.text != ""', 'user').order("random()")
    @_marked_posts_by_users
  end

  def posts_for_training
    if @_posts_for_training.nil?
      @_posts_for_training = []
      @_posts_for_testing = []

      marked_posts_by_users.each do |post| 
        if rand(2).zero?
          @_posts_for_training << post
        else
          @_posts_for_testing << post
        end
      end
    end

    @_posts_for_training
  end

  def posts_for_testing
    posts_for_training
    @_posts_for_testing
  end
end