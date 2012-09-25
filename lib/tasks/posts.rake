require 'stuff-classifier'

store = StuffClassifier::FileStorage.new("#{Rails.root}/vendor/assets/classifiers/stuff-classifier")
StuffClassifier::Base.storage = store

results = {:correct => 0, :incorrect => 0, :correct_real => 0, :incorrect_real => 0, :correct_spam => 0, :incorrect_spam => 0}

namespace :posts do
  task :mark_spam => :environment do

    cls = StuffClassifier::Bayes.new("Spam or Real", :storage => store)
    posts = Post.where("in_reply_to_user_id IS NOT NULL and user_id NOT IN (31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374, 31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374) AND text != ''").order("posts.created_at DESC")
    posts.each_with_index do |post, i|
      
      subject = post.text
      if subject.is_a? String
        begin
          cleaned = subject.dup.force_encoding('UTF-8')
          unless cleaned.valid_encoding?
            cleaned = subject.encode( 'UTF-8', 'Windows-1252' )
          end
          subject = cleaned
        rescue EncodingError
          subject.encode!( 'UTF-8', invalid: :replace, undef: :replace )
        end
      end

      if cls.classify(subject) == :real
        post.autospam = false
      else
        post.autospam = true
      end
        
      if post.spam == true
        if post.autospam
          results[:correct_spam] += 1
        else
          results[:incorrect_real] += 1
        end
      elsif post.spam === false
        if post.autospam == false
          results[:correct_real] += 1
        else
          results[:incorrect_spam] += 1
        end
      end

      if post.spam == false
        puts "Spam = #{post.autospam}: #{subject}"
      end
      
      post.save
      cls.save_state

    end

    # Precision (identifying real): 100.0%
    # Recall (identifying real): 98.68421052631578%

    # Precision (identifying real): 97.35449735449735%
    # Recall (identifying real): 98.3957219251337%

    #### pull new data

    # Precision (identifying real): 94.33962264150944%
    # Recall (identifying real): 94.33962264150944%

    puts "\n Precision (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_real])*100}%"
    puts " Recall (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_spam])*100}%"
  end

  task :train_spam => :environment do

    cls = StuffClassifier::Bayes.new("Spam or Real", :storage => store)
    #posts = Post.joins(:user).select(['users.twi_screen_name', 'posts.created_at', :engagement_type, :in_reply_to_user_id, :in_reply_to_post_id, :text, 'posts.id', :spam]).where("spam IS NULL AND in_reply_to_user_id IS NOT NULL and user_id NOT IN (31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374, 31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374) AND text != ''").limit(500).order("posts.created_at DESC")
    posts = Post.where("spam IS NULL AND in_reply_to_user_id IS NOT NULL and user_id NOT IN (31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374, 31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374)").order("posts.created_at DESC")
    posts.each_with_index do |post, i|
      
      #next if post.text.length > 10# or post.text.length == 0 or post.text[0] == '@'


      subject = post.text
      subject = '' if post.text.nil?
      if subject.is_a? String
        begin
          cleaned = subject.dup.force_encoding('UTF-8')
          unless cleaned.valid_encoding?
            cleaned = subject.encode( 'UTF-8', 'Windows-1252' )
          end
          subject = cleaned
        rescue EncodingError
          subject.encode!( 'UTF-8', invalid: :replace, undef: :replace )
        end
      end

      puts "\n#{post.id}: #{subject}"
      print "Spam? (s/r/n) "
      is_spam_str = STDIN.gets.chomp

      if is_spam_str == 's'
        cls.train(:spam, subject)
        post.spam = true

        if cls.classify(subject) == :spam
          results[:correct] += 1
          results[:correct_spam] += 1
        elsif 
          results[:incorrect] += 1
          results[:incorrect_spam] += 1
        end

      elsif is_spam_str == 'r'
        cls.train(:real, subject) 
        post.spam = false
        post.save

        if cls.classify(subject) == :real
          results[:correct] += 1
          results[:correct_real] += 1
        elsif 
          results[:incorrect] += 1
          results[:incorrect_real] += 1
        end

      else
        next
      end
      
      post.save
      cls.save_state

      puts "\n Precision (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_real])*100}%"
      puts "\n Recall (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_spam])*100}%"
      # puts "\n Precision (identifying spam): #{results[:correct_spam].to_f/(results[:correct_spam]+results[:incorrect_spam])*100}%"
      # puts "\n Recall (identifying spam): #{results[:correct_spam].to_f/(results[:correct_spam]+results[:incorrect_real])*100}%"

    end
  end

  task :build_truth_set_spam => :environment do

    cls = StuffClassifier::Bayes.new("Spam or Real", :storage => store)
    posts = Post.where("spam IS NULL AND in_reply_to_user_id IS NOT NULL and user_id NOT IN (31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374, 31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374) AND text != ''").limit(100).order("posts.created_at DESC")
    #posts = Post.where("engagement_type = 'pm' AND spam IS NULL AND in_reply_to_user_id IS NOT NULL and user_id NOT IN (31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374, 31, 2, 18, 108, 19, 191, 227, 231, 66, 284, 308, 223, 310, 309, 322, 324, 325, 326, 22, 374) AND text != ''").order("posts.created_at DESC")
    posts.each_with_index do |post, i|
      
      subject = post.text
      if subject.is_a? String
        begin
          cleaned = subject.dup.force_encoding('UTF-8')
          unless cleaned.valid_encoding?
            cleaned = subject.encode( 'UTF-8', 'Windows-1252' )
          end
          subject = cleaned
        rescue EncodingError
          subject.encode!( 'UTF-8', invalid: :replace, undef: :replace )
        end
      end

      puts "\n#{post.id}: #{subject}"
      print "Spam? (s/r/n) "
      is_spam_str = STDIN.gets.chomp

      if is_spam_str == 's'
        # cls.train(:spam, subject)
        post.spam = true

        if cls.classify(subject) == :spam
          results[:correct] += 1
          results[:correct_spam] += 1
        elsif 
          results[:incorrect] += 1
          results[:incorrect_spam] += 1
        end

      elsif is_spam_str == 'r'
        # cls.train(:real, subject) 
        post.spam = false
        post.save

        if cls.classify(subject) == :real
          results[:correct] += 1
          results[:correct_real] += 1
        elsif 
          results[:incorrect] += 1
          results[:incorrect_real] += 1
        end

      else
        next
      end
      
      post.save
      # cls.save_state

      # puts "\n Precision (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_real])*100}%"
      # puts "\n Recall (identifying real): #{results[:correct_real].to_f/(results[:correct_real]+results[:incorrect_spam])*100}%"
      # puts "\n Precision (identifying spam): #{results[:correct_spam].to_f/(results[:correct_spam]+results[:incorrect_spam])*100}%"
      # puts "\n Recall (identifying spam): #{results[:correct_spam].to_f/(results[:correct_spam]+results[:incorrect_real])*100}%"

    end
  end

end