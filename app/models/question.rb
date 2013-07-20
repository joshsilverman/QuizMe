class Question < ActiveRecord::Base
	has_many :posts
  has_many :in_reply_to_posts, :class_name => 'Post', :foreign_key => 'in_reply_to_question_id'

  has_many :answers
  has_many :publications
  has_many :question_moderations
  
  belongs_to :topic
  belongs_to :user
  belongs_to :asker, :foreign_key => :created_for_asker_id

  has_many :badges, :through => :requirements
  has_many :requirements

  scope :not_us, -> { where('user_id NOT IN (?)', Asker.all.collect(&:id) + ADMINS) }
  scope :ugc, -> { where('questions.user_id not in (?)', Asker.all.collect(&:id) + ADMINS) }

  scope :priority, -> { where('priority = ?', true) }
  scope :not_priority, -> { where('priority = ?', false) }

  scope :approved, -> { where('status = 1') }

  scope :moderated_by_consensus, -> { where(moderation_trigger_type_id: 1) }
  scope :moderated_by_above_advanced, -> { where(moderation_trigger_type_id: 2) }
  scope :moderated_by_tiebreaker, -> { where(moderation_trigger_type_id: 3) }

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

  def needs_edits?
    return true if bad_answers or inaccurate or ungrammatical
    return false
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

  def self.requires_moderations moderator
    moderator = moderator.becomes(Moderator)
    return [] unless moderator.lifecycle_above?(3) # check if user is > regular
    return [] unless moderator.moderator_segment_above?(2) # greated than noob mod
    # return [] unless moderator.questions.approved.count > 4 # check if user has written enough questions

    question_ids_moderated_by_current_user = moderator.question_moderations.collect(&:question_id)
    question_ids_moderated_by_current_user = [0] if question_ids_moderated_by_current_user.empty?    

    Question.where('status = 0')\
      .where('moderation_trigger_type_id is null')\
      .where("questions.user_id <> ?", moderator.id)\
      .where("questions.id NOT IN (?)", question_ids_moderated_by_current_user)\
      .where("questions.created_for_asker_id IN (?)", moderator.follows.where("role = 'asker'").collect(&:id))\
      .order('questions.created_at DESC')\
      .limit(5)\
      .sort_by{|p| p.created_at}.reverse
  end

  def self.recently_published_ugc domain_start = 7, domain_end = 3
    Question.includes(:user, :in_reply_to_posts)\
      .approved\
      .where("questions.created_at > ? and questions.created_at < ?", domain_start.days.ago, domain_end.days.ago)\
      .ugc
  end

  def self.score_questions popularity_index = {}, scores = {}
    questions_with_publication_count = Question.approved\
      .select(["questions.*", "count(publications.id) as publication_count"])\
      .joins(:publications)\
      .includes(:answers)\
      .group("questions.id")


    question_answered_counts = Post.joins("LEFT OUTER JOIN posts AS parents on parents.id = posts.in_reply_to_post_id")\
      .where("parents.interaction_type = 1")\
      .where("posts.in_reply_to_question_id is not null")\
      .answers\
      .social\
      .group("posts.in_reply_to_question_id")\
      .count 

    # build question popularity index - status answers per publication
    questions_with_publication_count.each { |q| popularity_index[q.id] = question_answered_counts[q.id].to_f / q.publication_count.to_f }

    # mark most popular 25% of questions
    popular_question_ids = popularity_index.sort_by {|k,v| v}.reverse[0..(popularity_index.size * 0.25).ceil].collect { |e| e[0] }

    # score questions / build score hash
    questions_with_publication_count.each do |q| 
      scores[q.created_for_asker_id] ||= {}
      scores[q.created_for_asker_id][q.id] = q.score(popular_question_ids.include? q.id)
    end

    scores
  end

  def score is_popular, score = 0
    score += 2 if is_popular #is popular
    score += 1 if !Asker.ids.include? user_id # is ugc
    score += 1 if resource_url.present? # has resource
    score += 1 if hint.present? # has hint
    score += 1 if created_at > 2.weeks.ago # is recent
    
    message_length = TWI_MAX_SCREEN_NAME_LENGTH + 1 + text.size + 1 + TWI_SHORT_URL_LENGTH
    message_length_with_answers = TWI_MAX_SCREEN_NAME_LENGTH + 1 + text_with_answers.size + 1 + TWI_SHORT_URL_LENGTH
    score += 1 if message_length < 140 # fits into tweet
    score += 1 if message_length < 80 # is short
    score += 1 unless INCLUDE_ANSWERS.include?(id) and message_length_with_answers > 140 # unless handle should include answers, but doesn't fit
    score
  end

  def text_with_answers
    "#{text} (#{answers.shuffle.collect {|a| a.text}.join('; ')})"
  end

  def request_edits
    return false unless needs_edits?
    script = [
      "Your question needs some work before we can publish it, check out the feedback here: <link>",
      "The question your wrote needs some love before we can publish it, check out the feedback here: <link>",
      "A question you wrote needs some work, fix it up here: <link>"
    ].sample
    script.gsub! '<link>', "/askers/#{asker.id}/questions/#{id}"
    asker.send_private_message(user, script, {intention: "request question edits"})
  end

  ###THIS IS FOR IMPORTING FROM QB###
	require 'net/http'
  require 'uri'

  # @qb = Rails.env.production? ? 'http://questionbase.studyegg.com' : 'http://localhost:3001'
  @qb = 'http://questionbase.studyegg.com'

  def self.import_video_urls_from_qb
    egg_ids = {13 => 18, 14 => 19, 30 => 22, 28 => 374}

    egg_ids.each do |egg_id, created_for_asker_id|
      egg = Question.get_studyegg_details(egg_id)
      egg['chapters'].each do |ch|
        Question.save_lesson(ch, created_for_asker_id)
      end
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

  def self.save_lesson(lesson, created_for_asker_id)
    @lesson_id = lesson['id'].to_i
    if @lesson_id
      questions = Question.get_lesson_questions(@lesson_id)
      return if questions['questions'].nil?
      questions['questions'].each do |imported_q|
        q = Question.find_by(text: Question.clean_and_clip_question(imported_q['question']))
        next if q.nil?
        puts "\n\nid: #{q.id}"
        puts q.text

        resources = imported_q['resources'] || []
        puts resources.count
        resources.each do |r|
          next unless r['media_type'] == "video"
          q.resource_url = "http://www.youtube.com/embed/#{r['url']}?start=#{r['begin']}&end=#{r['end']}"
        end
        q.save
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
      puts res.body
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
end
