class ModerationsController < ApplicationController
  prepend_before_filter :check_for_authentication_token, :only => [:manage]
  before_filter :moderator?

  def manage
    moderator = current_user.becomes(Moderator)
    @posts = Post.requires_moderations(moderator)

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
    moderation = moderator.post_moderations.find_or_initialize_by_post_id params['post_id']
    moderation.update_attributes type_id: params['type_id']

    Post.trigger_split_test(moderator.id, 'mod request script (=> moderate answer)')

    render :json => moderation.reload.post.moderation_trigger_type_id.present? ? moderation.type_id : nil
  end
end