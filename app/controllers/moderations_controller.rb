class ModerationsController < ApplicationController
  prepend_before_filter :check_for_authentication_token, :only => [:manage]
  before_filter :moderator?

  def manage
    moderator = current_user.becomes(Moderator)
    excluded_posts = Moderation.where('created_at > ?', 30.days.ago)\
      .select(["post_id", "array_to_string(array_agg(type_id),',') as type_ids"]).group("post_id").all
    excluded_posts = excluded_posts.reject do |p|
      type_ids = p.type_ids.split ','

      if type_ids.count == 1
        true
      elsif (moderator.moderator_segment.present? and moderator.moderator_segment > 2)
        true if type_ids.count == 2 and type_ids.uniq.count == 2
      end
    end
    excluded_post_ids = excluded_posts.collect(&:post_id)
    post_ids_moderated_by_current_user = moderator.moderations.collect(&:post_id)
    excluded_post_ids = (excluded_post_ids + post_ids_moderated_by_current_user).uniq
    excluded_post_ids = [0] if excluded_post_ids.empty?
    
    @posts = Post.includes(:in_reply_to_question => :answers).linked_box\
			.joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id")\
		  .where("parents.question_id IS NOT NULL")\
		  .where("posts.in_reply_to_user_id IN (?)", moderator.follows.where("role = 'asker'").collect(&:id))\
		  .where("posts.user_id <> ?", moderator.id)\
		  .where("posts.id NOT IN (?)", excluded_post_ids)\
      .where('posts.created_at > ?', 30.days.ago)\
      .order('posts.created_at DESC').limit(10)\
      .sort_by{|p| p.created_at}.reverse

    @questions = []
    @engagements, @conversations = [@posts.map{|p|[p.id, p]}, []] #Post.grouped_as_conversations @posts
    @asker = User.find 8765
    @oneinbox = true
    @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name, :twi_profile_img_url]).map{|a| [a.id, {twi_screen_name: a.twi_screen_name, twi_profile_img_url: a.twi_profile_img_url}]}.flatten]
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }
    @display_notifications = Post.create_split_test(moderator.id, 'grading on mod manage displays actions via growl (mod => regular)', 'false', 'true')

    render 'feeds/manage'
  end

  def create
    moderator = current_user.becomes(Moderator)
    moderation = moderator.moderations.find_or_initialize_by_post_id params['post_id']
    moderation.update_attributes type_id: params['type_id']

    Post.trigger_split_test(moderator.id, 'mod request script (=> moderate answer)')

    render :json => moderation.reload.post.moderation_trigger_type_id.present? ? moderation.type_id : nil
  end
end