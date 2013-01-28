class CustomBayes < StuffClassifier::Bayes

  def classify(text, default=nil)
    puts 'here'

    # Find the category with the highest probability
    max_prob = @min_prob
    best = nil

    scores = cat_scores(text)
    scores.each do |score|
      cat, prob = score
      if prob > max_prob
        max_prob = prob
        best = cat
      end

      puts '-----'
      puts text
      puts cat
      puts prob
      puts ''
    end
    
    # Return the default category in case the threshold condition was
    # not met. For example, if the threshold for :spam is 1.2
    #
    #    :spam => 0.73, :ham => 0.40  (OK)
    #    :spam => 0.80, :ham => 0.70  (Fail, :ham is too close)

    return default unless best

    threshold = @thresholds[best] || 1.0

    scores.each do |score|
      cat, prob = score
      next if cat == best
      return default if prob * threshold > max_prob
    end

    return 12234    
  end

end