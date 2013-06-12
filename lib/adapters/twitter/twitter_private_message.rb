class TwitterPrivateMessage
	def initialize sender, recipient, text, options = {}
		@sender = sender
		@recipient = recipient
		@text = text
		@options = options
	end

  def perform
    short_url = nil
    if @options[:short_url]
      short_url = @options[:short_url]
    elsif @options[:long_url]
      short_url = Post.format_url(@options[:long_url], 'twi', @options[:link_type], @sender.twi_screen_name, @recipient.twi_screen_name) 
    end

    @text = "#{@text} #{short_url}" if @options[:include_url] and short_url

    begin
      res = Post.twitter_request { @sender.twitter.direct_message_create(@recipient.twi_user_id, @text) }
      post = Post.create(
        :user_id => @sender.id,
        :provider => 'twitter',
        :text => @text,
        :provider_post_id => res.present? ? res.id.to_s : 0,
        :in_reply_to_post_id => @options[:in_reply_to_post_id],
        :in_reply_to_user_id => @recipient.id,
        :conversation_id => @options[:conversation_id],
        :url => short_url,
        :posted_via_app => true,
        :requires_action => false,
        :interaction_type => 4,
        :intention => @options[:intention],
        :nudge_type_id => @options[:nudge_type_id]
      )

      if parent = post.parent 
        parent.update_attribute :requires_action, false
      end

      @recipient.segment
    rescue Exception => exception
      puts "exception in DM user"
      puts exception.message
    end
    
    return post  	
  end
end