class Question < ActiveRecord::Base
	has_many :posts
  has_many :answers
  has_many :publications
  belongs_to :topic
  belongs_to :user
  belongs_to :asker, :foreign_key => :created_for_asker_id

  has_many :badges, :through => :requirements
  has_many :requirements

  scope :not_us, where('user_id NOT IN (?)', Asker.all.collect(&:id) + ADMINS)

  scope :priority, where('priority = ?', true)
  scope :not_priority, where('priority = ?', false)

  scope :approved, where('status = 1')

  before_save :generate_slug

  def self.select_questions_to_post(asker, num_days_back_to_exclude, queue = [], priority_questions = [])
    user_grouped_priority_questions = asker.questions.approved.priority\
      .order("created_at ASC")\
      .group_by(&:user_id)

    # Sample one priority question per user
    user_grouped_priority_questions.each { |user_id, user_questions| queue << user_questions.sample.id if queue.size < asker.posts_per_day }

    # Fill queue with non-priority questions, non recent question
    if queue.size < asker.posts_per_day
      non_priority_questions = asker.questions.approved.not_priority
      
      recent_question_ids = asker.publications\
        .where("question_id is not null and published = ?", true)\
        .where("created_at > ?", num_days_back_to_exclude.days.ago)\
        .collect(&:question_id)
      recent_question_ids = [0] if recent_question_ids.blank? 

      queue += non_priority_questions.where("id not in (?)", recent_question_ids).sample(asker.posts_per_day - queue.size).collect(&:id)

      # Fill queue with recent questions
      if queue.size < asker.posts_per_day
        queue += non_priority_questions.where("id in (?)", recent_question_ids).sample(asker.posts_per_day - queue.size).collect(&:id)
      end
    end
    puts "WARNING THE QUEUE FOR #{asker.twi_screen_name} WAS NOT FULLY FILLED. ONLY #{queue.size} of #{asker.posts_per_day} POSTS SCHEDULED" if queue.size < asker.posts_per_day
    queue
  end

  def self.unmoderated_counts
    Question.where(:status => 0).group('created_for_asker_id').count
  end

  def self.counts
    Question.group('created_for_asker_id').count
  end

  def slug_text
    return self.text.gsub(' ', '-').gsub('&quot;', '').gsub(/[^0-9A-Za-z\-_]/, '').gsub(/-\z/, "")[0..69]
  end

  def generate_slug
    self.slug = self.slug_text if (self.slug.blank? and self.text.present?)
  end

  def correct_answer
    answers.select{|a| a.correct == true}[0] unless answers.empty?
  end

  def incorrect_answers
    answers.select{|a| a.correct != true} || []
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
        resources = q['resources'] || []
        resources.each do |r|
          next unless new_q.resource_url.blank? and r['media_type'] == "video"
          new_q.resource_url = "http://www.youtube.com/watch?v=#{r['url']}&t=#{r['begin']}"
        end
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
