class ModerationsController < ApplicationController
  before_filter :moderator?

  def manage
  	post_ids_with_enough_moderations = Post.requires_action.select('posts.id').joins(:moderations).group('posts.id').having('count(moderations.id) > 1').collect(&:id)
		
		@posts = Post.includes(:tags, :conversation).linked_box.not_dm\
			.joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id")\
		  .where("parents.question_id IS NOT NULL")\
		  .where("posts.in_reply_to_user_id IN (?)", current_user.follows.where("role = 'asker'").collect(&:id))\
		  .where("posts.user_id <> ?", current_user.id)\
		  .where("posts.id NOT IN (?)", post_ids_with_enough_moderations)\
			.order('random()').limit(10)\
      .sort_by{|p| p.created_at}.reverse

    @questions = []
    @engagements, @conversations = Post.grouped_as_conversations @posts
    @asker = User.find 8765
    @oneinbox = true
    @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name]).map{|a| [a.id, a.twi_screen_name]}.flatten]
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }

    render 'feeds/manage'
  end

  def create
    moderation = current_user.moderations.find_or_initialize_by_post_id params['post_id']
    moderation.update_attributes type_id: params['type_id']

    Post.trigger_split_test(current_user.id, 'mod request script (=> moderate answer)')
    render status: 200, nothing: true
  end

end