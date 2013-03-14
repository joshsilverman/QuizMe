class Classifier
  def initialize domain = 250, opts = {:interaction_type => true, :twi_screen_name => false, :previous_spam => false, :previous_real => false, :stem_links => true}
    @domain = domain
    @opts = opts

    @store = StuffClassifier::FileStorage.new("#{Rails.root}/lib/classifiers/stuff-classifier")
    StuffClassifier::Base.storage = @store
    @stuff_classifier = StuffClassifier::Bayes.new("Spam or Real", :storage => @store) #, :thresholds => {:spam => .1, :real => 5.0})
  end

  def classify_all
    puts <<-EOS

      Running classifier on all posts by users
    EOS
    precision, recall, ci, spam_precision, spam_recall = classify_set posts_by_users
    out = <<-EOS

      Results for whole corpus including truthset:
        Posts by users (excl. RTs):#{posts_by_users.count}
        Truthset:#{posts_by_users.count}
        Training set:#{posts_for_training.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}

        Precision on detecting spam:#{spam_precision}
        Recall on detecting spam:#{spam_recall}
    EOS
    puts out

    out
  end

  def classify_testing_set
    puts <<-EOS

      Running classifier on testing set
    EOS
    precision, recall, ci, spam_precision, spam_recall = classify_set posts_for_testing
    puts <<-EOS

      Results for testing:
        Testing set:#{posts_for_testing.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}

        Precision on detecting spam:#{spam_precision}
        Recall on detecting spam:#{spam_recall}
    EOS
  end

  def classify_training_set
    puts <<-EOS

      Running classifier on training set (results should be excellent)
    EOS
    precision, recall, ci, spam_precision, spam_recall = classify_set posts_for_training
    puts <<-EOS

      Results for training:
        Training set:#{posts_for_training.count}

        Precision on detecting real:#{precision}
        Recall on detecting real:#{recall}
        Confidence interval (95% confidence level):#{ci}

        Precision on detecting spam:#{spam_precision}
        Recall on detecting spam:#{spam_recall}
    EOS
  end

  def classify_set posts
    results = {:real => {:correct => 0, :incorrect => 0}, :spam => {:correct => 0, :incorrect => 0}}
    posts.each do |post|
      klass, correct = classify(post)
      results[klass][correct] += 1 if correct != nil
    end

    real = results[:real][:correct] + results[:spam][:incorrect]
    correctly_detected_real = results[:real][:correct]
    detected_real = results[:real][:correct] + results[:real][:incorrect]

    spam = results[:spam][:correct] + results[:real][:incorrect]
    correctly_detected_spam = results[:spam][:correct]
    detected_spam = results[:spam][:correct] + results[:spam][:incorrect]

    precision = correctly_detected_real.to_f/detected_real if detected_real
    recall = correctly_detected_real.to_f/real if real
    ci = confidence_interval posts_by_users.count, posts_by_users.count, recall

    spam_precision = correctly_detected_spam.to_f/detected_spam if detected_spam
    spam_recall = correctly_detected_spam.to_f/spam if spam

    puts results

    return precision, recall, ci, spam_precision, spam_recall
  end

  def train

    puts <<-EOS
      Training classifier
    EOS
    purge_classifier

    spams = Post.where(:spam => true).where("text IS NOT NULL").order("random()")
    spams.each_with_index do |post, i|
      vector = build_feature_vector(post)
      @stuff_classifier.train(:spam, vector)
    end

    real = Post.where('id IN (?)', Post.select([:in_reply_to_post_id]).where("text IS NOT NULL").where('in_reply_to_post_id IS NOT NULL').collect(&:in_reply_to_post_id)).order("random()")
    real.each_with_index do |post, i|
      vector = build_feature_vector(post)
      @stuff_classifier.train(:real, vector)
    end

    @stuff_classifier.save_state
  end

  #private

  def classify post

    #statisticalelse
    vector = build_feature_vector(post)
    klass = @stuff_classifier.classify(vector, :real)
    if klass == :spam
      post.update_attribute :autospam, true

      # verify 20 pieces of spam every 24 hours
      if Post.spam.requires_action.where("created_at > ?", Time.now - 1.day).count >= 20
        post.update_attribute :requires_action, false
      end
    else
      post.update_attribute :autospam, false
    end


    truth_val = post.spam
    truth_val = false if truth_val == nil

    # if klass == :spam and truth_val == false
    #   puts <<-EOS

    #     Classifier thought this was spam: #{vector}
    #     Was it correct?
    #   EOS
    #   if STDIN.gets.chomp == "y"
    #     post.update_attribute :spam, true
    #     truth_val = true
    #   end
    # end

    # if klass == :real and truth_val == true
    #   puts <<-EOS

    #     #{vector}
        
    #   EOS
    #   # STDIN.gets.chomp
    # end

    # puts <<-EOS
    #   #{klass}: #{vector}
    # EOS

    grade = :correct if truth_val == post.autospam
    grade = :incorrect if truth_val != post.autospam

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
    @_posts_by_users ||= Post.includes(:user).where("users.role = 'user' AND posts.text != ''").where(:posted_via_app => false).order("random()").limit @domain
    @_posts_by_users
  end

  def posts_for_training
    if @_posts_for_training.nil?
      @_posts_for_training = []
      @_posts_for_testing = []

      posts_by_users.each do |post| 
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

  def build_feature_vector(post)
    if post.interaction_type == 4
      interaction_type = 'directmessage'
    elsif post.interaction_type == 2
      interaction_type = 'atmention'
    end

    vector = post.text || ""

    vector = "#{interaction_type} " + vector if @opts[:interaction_type]

    vector = "#{post.user_id} " + vector

    vector = "#{"hasparent" unless post.in_reply_to_post_id.nil?} " + vector
    vector = "#{"noparent" if post.in_reply_to_post_id.nil?} " + vector

    vector = "#{post.user.twi_screen_name} " + vector if @opts[:twi_screen_name]

    if @opts[:previous_spam]
      if Post.where(:user_id => post.user_id).where(:spam => true).count > 0
        vector = "previous_spam " + vector
      end
    end

    if @opts[:previous_real]
      if Post.where(:user_id => post.user_id).where(:spam => nil).count > 0
        vector = "previous_real " + vector
      end
    end

    if @opts[:stem_links]
      vector = vector.gsub(/http:\/\/[^\s]+/, 'link')
      vector = "nolink " + vector if vector.index('link').nil?
    end

    vector
  end
end