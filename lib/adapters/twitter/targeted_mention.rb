class TargetedMention
	def initialize asker, targeted_user, options = {}
		@asker = asker
    @targeted_user = targeted_user
	end

  def perform
    return unless @asker.targeted_mention_count > @asker.posts.where('created_at > ?', Time.now.beginning_of_day).where("intention = 'targeted mention'").count
    @asker.send_targeted_mention(@targeted_user)
  end

  def max_attempts
    return 3
  end
end