require 'amatch'
include Amatch

class Grader
  def initialize feature_names = [:sellers, :longest_substring]
    @feature_names = feature_names

    @thresholds = {
      :sellers => {
        :correct => 0.7,
        :incorrect => 0.92
      },
      :longest_substring => {
        :correct => 0.7,
        :incorrect => 0.9
      }
    }
  end

  def grade id_or_posts_or_post
    id = id_or_posts_or_post if id_or_posts_or_post.is_a? Integer
    posts = id_or_posts_or_post.where("autocorrect IS NULL").includes(:conversation => {:post => :user, :publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}, :parent => {:publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}) if id_or_posts_or_post.is_a? ActiveRecord::Relation
    posts = [Post.not_spam.includes(:conversation => {:post => :user, :publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}, :parent => {:publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}).find_by_id(id_or_posts_or_post.id)] if id_or_posts_or_post.is_a? Post

    posts = [Post.not_spam.includes(:conversation => {:post => :user, :publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}, :parent => {:publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}).find_by_id(id)] if id
    # posts = Post.not_spam.includes(:conversation => {:post => :user, :publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}, :parent => {:publication => {:question => {:answers => nil, :publications => {:conversations => :posts}}}}).order('created_at DESC').limit 2000 unless id or posts
    
    return if posts.blank?

    correct = incorrect = missed = error = 0
    posts.each do |post|
      next if post.provider == 'wisr' # exclude where posted through app
      next if post.posted_via_app # exclude where posted through app

      _autocorrect = autocorrect post
      post.update_attribute :autocorrect, _autocorrect if _autocorrect == true or _autocorrect == false
      if _autocorrect == post.correct
        correct += 1
      elsif _autocorrect == -1
        error +=1
      elsif _autocorrect != post.correct and !_autocorrect.nil?
        incorrect += 1
      else
        missed += 1
      end
    end

    # puts @thresholds.to_yaml
    # puts <<-EOS
    #   Autograde correct: #{correct}
    #   Autograde incorrect: #{incorrect}
    #   Autograde missed: #{missed}
    #   Autograde error: #{error}

    #   Precision: #{correct.to_f/(correct + incorrect)}
    #   Recall (linked): #{correct.to_f/(correct + incorrect + missed)}
    #   Recall (all): #{correct.to_f/(correct + incorrect + missed + error)}

    # EOS
  end

  def autocorrect post
    question = post.link_to_question
    return -1 unless question

    answer_posts = get_answer_posts question

    correct_vector = build_match_vector post, answer_posts[:correct]
    incorrect_vector = build_match_vector post, answer_posts[:incorrect]
    _autocorrect, decisive_feature  = vectors_to_autocorrect correct_vector, incorrect_vector

    _autocorrect
  end

  private

  def vectors_to_autocorrect correct_vector, incorrect_vector
    @feature_names.each do |feature_name|
      correct_score = correct_vector[feature_name][:max] || 0
      incorrect_score = incorrect_vector[feature_name][:max] || 0
      correct_match_threshold = @thresholds[feature_name][:correct]
      incorrect_match_threshold = @thresholds[feature_name][:incorrect]

      if correct_score > correct_match_threshold and incorrect_score > incorrect_match_threshold
        return true if correct_score >= incorrect_score
        return false
      elsif correct_score > correct_match_threshold
        return true, feature_name
      elsif incorrect_score > incorrect_match_threshold
        return false, feature_name
      end
    end

    nil
  end

  def get_answer_posts question
    answer_posts = correct = incorrect = []
    if question
      answer_posts = question.publications.map{|pub| pub.conversations.map{|c| c.posts}}.flatten
      correct = answer_posts.select{|p| p.correct == true} 
      correct += [question.correct_answer] if question.correct_answer
      incorrect = answer_posts.select{|p| p.correct == false} + question.incorrect_answers
    end
    return {:correct => correct, :incorrect => incorrect}
  end

  def build_match_vector post, answer_posts
    vector = Hash[*@feature_names.collect { |f| [f, 0] }.flatten]
    @feature_names.each do |feature_name|
      feature_pre_reduce = {}
      answer_posts.each do |answer_post|
        next if answer_post.id == post.id # exclude self-comparison during testing
        feature_pre_reduce[match(feature_name, answer_post, post)] = "#{answer_post.text} (#{answer_post.id} - #{answer_post.class})"
      end
      max = feature_pre_reduce.keys.max
      vector[feature_name] = {:max => max, :match => feature_pre_reduce[max]}
    end
    vector
  end

  def match match_alg, prev_post, curr_post
    prev_text = prev_post.clean_text.downcase if prev_post.respond_to? 'clean_text'
    prev_text ||= prev_post.text.downcase
    self.send match_alg, prev_text, curr_post.clean_text.downcase
  end

  def sellers pattern, subject
    sellers = Sellers.new(pattern).match(subject)
    max_sellers = [pattern.length, subject.length].max
    1 - sellers.to_f/max_sellers # normalize
  end

  def levenshtein
  end

  def hamming
  end

  def pair_distance
  end

  def longest_subsequence
  end

  def longest_substring pattern, subject
    longest_substring = LongestSubstring.new(pattern).match(subject)
    min_longest_substring = [pattern.length, subject.length].min
    min_longest_substring = 4 if min_longest_substring < 4
    normalized_score = longest_substring.to_f/min_longest_substring || 0
    normalized_score = 0 if normalized_score.nan?
    normalized_score
  end

  def jaro
  end

  def jaro_winkler
  end


  # def test


  #   m = Levenshtein.new("pattern")
  #   # => #<Amatch::Levenshtein:0x4035919c>
  #   m.match("pattren")
  #   # => 2
  #   m.search("abcpattrendef")
  #   # => 2
  #   "pattern language".levenshtein_similar("language of patterns")
  #   # => 0.2

  #   m = Hamming.new("pattern")
  #   # => #<Amatch::Hamming:0x40350858>
  #   m.match("pattren")
  #   # => 2
  #   "pattern language".hamming_similar("language of patterns")
  #   # => 0.1

  #   m = PairDistance.new("pattern")
  #   # => #<Amatch::PairDistance:0x40349be8>
  #   m.match("pattr en")
  #   # => 0.545454545454545
  #   m.match("pattr en", nil)
  #   # => 0.461538461538462
  #   m.match("pattr en", /t+/)
  #   # => 0.285714285714286
  #   "pattern language".pair_distance_similar("language of patterns")
  #   # => 0.928571428571429

  #   m = LongestSubsequence.new("pattern")
  #   # => #<Amatch::LongestSubsequence:0x4033e900>
  #   m.match("pattren")
  #   # => 6
  #   "pattern language".longest_subsequence_similar("language of patterns")
  #   # => 0.4

  #   m = LongestSubstring.new("pattern")
  #   # => #<Amatch::LongestSubstring:0x403378d0>
  #   m.match("pattren")
  #   # => 4
  #   "pattern language".longest_substring_similar("language of patterns")
  #   # => 0.4

  #   m = Jaro.new("pattern")
  #   # => #<Amatch::Jaro:0x363b70>
  #   m.match("paTTren")
  #   # => 0.952380952380952
  #   m.ignore_case = false
  #   m.match("paTTren")
  #   # => 0.742857142857143
  #   "pattern language".jaro_similar("language of patterns")
  #   # => 0.672222222222222

  #   m = JaroWinkler.new("pattern")
  #   # #<Amatch::JaroWinkler:0x3530b8>
  #   m.match("paTTren")
  #   # => 0.971428571712403
  #   m.ignore_case = false
  #   m.match("paTTren")
  #   # => 0.79428571505206
  #   m.scaling_factor = 0.05
  #   m.match("pattren")
  #   # => 0.961904762046678
  #   "pattern language".jarowinkler_similar("language of patterns")
  #   # => 0.672222222222222
  # end
end