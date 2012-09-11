class Question < ActiveRecord::Base
	has_many :posts
  has_many :answers
  belongs_to :topic
  belongs_to :user

  def self.select_questions_to_post(asker, num_days_back_to_exclude)
    recent_question_ids = asker.publications.where("question_id is not null and published = ?", true).order('created_at DESC').limit(num_days_back_to_exclude * asker.posts_per_day).collect(&:question_id)
    recent_question_ids = recent_question_ids.empty? ? [0] : recent_question_ids
    priority_questions = Question.where("created_for_asker_id = ? and priority = ?", asker.id, true).collect(&:id)
    questions = Question.where("created_for_asker_id = ? and id not in (?) and status = 1", asker.id, recent_question_ids+priority_questions).includes(:answers)
    id_queue = priority_questions.sample(asker.posts_per_day) 
    id_queue += questions.sample(asker.posts_per_day - id_queue.size)
    puts "WARNING THE QUEUE FOR #{asker.twi_screen_name} WAS NOT FULLY FILLED. ONLY #{id_queue.size} of #{asker.posts_per_day} POSTS SCHEDULED" if id_queue.size < asker.posts_per_day
    return Question.where("id in (?)", id_queue)
    #@TODO email or some notification that I will actually read if not filled
  end


  ###THIS IS FOR IMPORTING FROM QB###
	require 'net/http'
  require 'uri'

  @qb = Rails.env.production? ? 'http://questionbase.studyegg.com' : 'http://localhost:3001'

  def self.import_studyegg_from_qb(egg_id, topic_name, created_for_asker_id)
    egg = Question.get_studyegg_details(egg_id)
    egg['chapters'].each do |ch|
      Question.save_lesson(ch, topic_name, created_for_asker_id)
    end
  end  

  def self.get_studyegg_details(egg_id)
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_details/#{egg_id}.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyegg = JSON.parse(res.body)
    rescue
      studyegg=nil
    end
    return studyegg
  end

  def self.save_lesson(lesson, topic_name, created_for_asker_id)
    @lesson_id = lesson['id'].to_i
    if @lesson_id
      questions = Question.get_lesson_questions(@lesson_id)
      return if questions['questions'].nil?
      topic = Topic.find_or_create_by_name(topic_name)
      questions['questions'].each do |q|
        new_q = Question.find_or_create_by_text(Question.clean_and_clip_question(q['question']))
        new_q.topic_id = topic.id
        new_q.created_for_asker_id = created_for_asker_id
        new_q.status = 1
        new_q.user_id = 1
        # new_q.qb_lesson_id = @lesson_id
        # new_q.qb_q_id = q['id']
        new_q.save
        q['answers'].each do |a|
          ans = Answer.find_or_create_by_text(:text => Question.clean_text(a['answer']))
          ans.correct = a['correct']
          ans.question_id = new_q.id
          ans.save
        end
      end
    end
  end

  def self.get_lesson_questions(lesson_id)
    url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{lesson_id}.json")
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    begin
      studyegg = JSON.parse(res.body)
    rescue
      studyegg = nil
    end
    return studyegg
  end

  def self.clean_and_clip_question(quest)
    if quest[0..3].downcase=='true'
      i = quest.downcase.index('false')
      quest = "T\\F: "+ quest[(i+7)..-1]
    end
    clean_text(quest)
  end

  def self.clean_text(a)
    a.gsub!('<sub>','')
    a.gsub!('</sub>','')
    a.gsub!('<sup>-</sup>','-')
    a.gsub!('<sup>+</sup>','+')
    a.gsub!('<sup>','^')
    a.gsub!('</sup>','')
    a
  end

  # def self.get_lesson_details(lesson)
  #   url = URI.parse("#{@qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_lesson_details/#{lesson}")
  #   req = Net::HTTP::Get.new(url.path)
  #   res = Net::HTTP.start(url.host, url.port) {|http|
  #     http.request(req)
  #   }
  #   begin
  #     studyeggs = JSON.parse(res.body)
  #   rescue
  #     studyeggs = []
  #   end
  #   return studyeggs
  # end

  # def self.import_lesson_from_qb(lesson_id, topic_name)
  #   lesson = Question.get_lesson_details(lesson_id.to_s)
  #   lesson.each do |l|
  #     Question.save_lesson(l, topic_name)
  #   end
  # end

  # def self.import_data_from_qmm
  #   url = URI.parse("http://studyegg-quizme.herokuapp.com/db.json")
  #   req = Net::HTTP::Get.new(url.path)
  #   res = Net::HTTP.start(url.host, url.port) {|http|
  #     http.request(req)
  #   }
  #   begin
  #     questions = JSON.parse(res.body)
  #   rescue
  #     questions = nil
  #   end
  #   return questions
  # end  
end
