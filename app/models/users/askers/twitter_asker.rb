class TwitterAsker < Asker

	def send_public_message text, options = {}, recipient = nil
    sender = self

    options[:resource_url] = options[:resource_url].gsub(/\/embed\/([^\?]*)\?start=([0-9]+)&end=[0-9]+/,'/watch?v=\\1&t=\\2') if options[:resource_url] =~ /^http:\/\/www.youtube.com\/embed\//
    short_url = Post.format_url(options[:long_url], 'twi', options[:link_type], sender.twi_screen_name, options[:reply_to]) if options[:long_url]
    answers = "(#{Question.includes(:answers).find(Publication.find(options[:publication_id]).question_id).answers.shuffle.collect {|a| a.text}.join('; ')})" if (options[:publication_id].present? and options[:include_answers])

    tweet = Post.format_tweet(text, {
      :in_reply_to_user => options[:reply_to],
      :question_backlink => short_url,
      :hashtag => options[:hashtag],
      :resource_backlink => options[:resource_url],
      :via_user => options[:via],
      :wisr_question => options[:wisr_question],
      :answers => answers,
      :recipient_id => options[:in_reply_to_user_id],
      :sender_id => sender.id
    })

    failure_message = "Tweet (#{options[:intention]}, #{options[:is_reengagement]}) from #{twi_screen_name} to #{options[:reply_to]}: #{text}"

    if options[:in_reply_to_post_id] and options[:link_to_parent]
      parent_post = Post.find(options[:in_reply_to_post_id])
      twitter_response = Post.twitter_request(failure_message) { sender.twitter.update(tweet, {'in_reply_to_status_id' => parent_post.provider_post_id.to_i}) }
    else
      twitter_response = Post.twitter_request(failure_message) { sender.twitter.update(tweet) }
    end
    if twitter_response
      post = Post.create(
        :user_id => sender.id,
        :provider => 'twitter',
        :text => tweet,
        :provider_post_id => twitter_response.present? ? twitter_response.id.to_s : 0,
        :in_reply_to_post_id => options[:in_reply_to_post_id],
        :in_reply_to_user_id => options[:in_reply_to_user_id],
        :conversation_id => options[:conversation_id],
        :publication_id => options[:publication_id],
        :url => options[:long_url] ? short_url : nil,
        :posted_via_app => true,
        :requires_action => (options[:requires_action].present? ? options[:requires_action] : false),
        :interaction_type => options[:interaction_type] || 2,
        :correct => options[:correct],
        :intention => options[:intention],
        :question_id => options[:question_id],
        :in_reply_to_question_id => options[:in_reply_to_question_id],
        :is_reengagement => options[:is_reengagement]
      )
      Post.find(options[:in_reply_to_post_id]).update(requires_action: false) if options[:in_reply_to_post_id]

      if options[:publication_id]
        publication = Publication.find(options[:publication_id])
        publication.posts << post
      end

			if options[:is_reengagement]
				MP.track_event "reengaged inactive", {
					success: true,
					distinct_id: options[:in_reply_to_user_id],
					interval: options[:interval],
					strategy: options[:strategy],
					backlog: options[:is_backlog],
					asker: self.twi_screen_name
				}
			end
		else
			if options[:is_reengagement]
				MP.track_event "reengaged inactive", {
					success: false,
					distinct_id: options[:in_reply_to_user_id],
					interval: options[:interval],
					strategy: options[:strategy],
					backlog: options[:is_backlog],
					asker: self.twi_screen_name
				}
			end
    end
    return post
  end

  def send_private_message recipient, text, options = {}
    sender = self

    short_url = nil
    if options[:short_url]
      short_url = options[:short_url]
    elsif options[:long_url]
      short_url = Post.format_url(options[:long_url], 'twi', options[:link_type], sender.twi_screen_name, recipient.twi_screen_name)
    end

    text = "#{text} #{short_url}" if options[:include_url] and short_url

    begin
      failure_message = "DM (#{options[:intention]}, #{options[:is_reengagement]}) from #{twi_screen_name} to #{recipient.try(:twi_screen_name)}: #{text}"

      res = Post.twitter_request(failure_message) { sender.twitter.direct_message_create(recipient.twi_user_id, text) }
      post = Post.create(
        :user_id => sender.id,
        :provider => 'twitter',
        :text => text,
        :provider_post_id => res.present? ? res.id.to_s : 0,
        :in_reply_to_post_id => options[:in_reply_to_post_id],
        :in_reply_to_user_id => recipient.id,
        :conversation_id => options[:conversation_id],
        :url => short_url,
        :posted_via_app => true,
        :requires_action => false,
        :interaction_type => 4,
        :intention => options[:intention],
        :nudge_type_id => options[:nudge_type_id],
        :question_id => options[:question_id],
        :is_reengagement => options[:is_reengagement]
      )
      Post.find(options[:in_reply_to_post_id]).update(requires_action: false) if options[:in_reply_to_post_id]
    rescue Exception => exception
      puts "exception in DM user"
      puts exception.message
    end
    return post
  end
end
