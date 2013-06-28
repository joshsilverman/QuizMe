class ModerationsController < ApplicationController
  before_filter :moderator?
  before_filter :check_for_authentication_token, :only => [:manage]

  def manage
    moderator = current_user.becomes(Moderator)
    # conversations w/ multiple requires action posts being moderated, triggering multiple responses, dupe status errors
    # need to filter out posts from conversations that already have grades, Post id: 965010

    # get all posts w/ more than one mod
    excluded_posts = Post.requires_action.joins(:moderations).group('posts.id').having('count(moderations.id) > 1')
    # allow tiebreaker if mod is qualified
    excluded_posts.reject! {|p| p.moderations.count == 2 and p.moderations.collect(&:type_id).uniq.count == 2 } if (moderator.moderator_segment.present? and moderator.moderator_segment > 2)    
    excluded_post_ids = excluded_posts.collect(&:id)

    post_ids_moderated_by_current_user = moderator.moderations.collect(&:post_id)
    excluded_post_ids = (excluded_post_ids + post_ids_moderated_by_current_user).uniq
    excluded_post_ids = [0] if excluded_post_ids.empty?
		
		@posts = Post.includes(:tags, :conversation, :in_reply_to_question => :answers).linked_box\
			.joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id")\
		  .where("parents.question_id IS NOT NULL")\
		  .where("posts.in_reply_to_user_id IN (?)", moderator.follows.where("role = 'asker'").collect(&:id))\
		  .where("posts.user_id <> ?", moderator.id)\
		  .where("posts.id NOT IN (?)", excluded_post_ids)\
      .order('posts.created_at DESC').limit(10)\
      .sort_by{|p| p.created_at}.reverse

    @questions = []
    @engagements, @conversations = [@posts.map{|p|[p.id, p]}, []] #Post.grouped_as_conversations @posts
    @asker = User.find 8765
    @oneinbox = true
    @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name]).map{|a| [a.id, a.twi_screen_name]}.flatten]
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }

    render 'feeds/manage'
  end

  def create
    moderator = current_user.becomes(Moderator)
    moderation = moderator.moderations.find_or_initialize_by_post_id params['post_id']
    moderation.update_attributes type_id: params['type_id']

    Post.trigger_split_test(moderator.id, 'mod request script (=> moderate answer)')
    render status: 200, nothing: true
  end

end