module Adapters
  module WisrFeed
  end
end

module Adapters::WisrFeed::Post
  def self.save_or_update post
    begin
      request = build_request(post)
      send_request(request)
    rescue
    end
  end

  def self.http
    @@_http ||= Net::HTTP.new(Adapters::WisrFeed::URL, Adapters::WisrFeed::PORT)
  end

  def self.build_request post
    request = Net::HTTP::Post.new("/api/asker_feeds")
    post_params = post_params(post)

    request.set_form_data(post_params)

    request
  end

  def self.send_request request
    http.request(request)
  end

  def self.post_params post
    post_params = [[:auth_token, Adapters::WisrFeed::AUTH_TOKEN]]

    post = Post.includes(:publication, :user, question: :answers).find(post.id)

    set_post_question_param(post, post_params)
    set_post_correct_answer_param(post, post_params)
    set_post_incorrect_answers_param(post, post_params)
    set_post_wisr_id_param(post, post_params)
    set_post_created_at_param(post, post_params)
    set_post_user_profile_image_urls_param(post, post_params)

    set_feed_wisr_id_param(post, post_params)
    set_feed_twi_name_param(post, post_params)
    
    post_params
  end

  def self.set_post_question_param post, post_params
    raise ArgumentError, 'no_question_error' if post.question.nil?

    question = post.question
    post_params << ["asker_feed[post][question]", question.text]
  end

  def self.set_post_correct_answer_param post, post_params
    raise ArgumentError, 'no_answers_error' if post.question.answers.empty?

    correct_answer = post.question.answers.select { |a| a.correct }.first
    post_params << ["asker_feed[post][correct_answer]", correct_answer.text]
  end

  def self.set_post_incorrect_answers_param post, post_params
    incorrect_answers = post.question.answers.select { |a| a.correct == false }

    incorrect_answers.each do |incorrect_answer|
      post_params << ["asker_feed[post][false_answers][]",incorrect_answer.text]
    end
  end

  def self.set_post_wisr_id_param post, post_params
    raise ArgumentError, 'no_publication' if post.publication.nil?

    post_params << ["asker_feed[post][wisr_id]", post.publication.id]
  end

  def self.set_post_created_at_param post, post_params
    post_params << ["asker_feed[post][created_at]",post.created_at]
  end

  def self.set_post_user_profile_image_urls_param post, post_params
    # post_params << ["asker_feed[post][created_at][]", '']
  end

  def self.set_feed_wisr_id_param post, post_params
    raise ArgumentError, 'no_user' if post.user.nil?
    raise ArgumentError, 'non_asker' if post.user.role != 'asker'

    post_params << ["asker_feed[wisr_id]", post.user.id]
  end

  def self.set_feed_twi_name_param post, post_params
    raise ArgumentError, 'no_user' if post.user.nil?
    raise ArgumentError, 'non_asker' if post.user.role != 'asker'

    post_params << ["asker_feed[twi_name]", post.user.twi_name]
  end
end