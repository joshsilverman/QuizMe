class ModerationsController < ApplicationController
  prepend_before_filter :check_for_authentication_token, :only => [:manage]
  before_filter :moderator?

  def manage
    moderator = current_user.becomes(Moderator)
    if params[:edits] == 'true'
      @posts = []
      @moderatables = Question.requires_moderations(moderator, {needs_edits_only: true}).sort_by {|m| m.created_at }.reverse
    elsif params[:all] == 'true' and moderator.is_admin?
      @posts = []
      @moderatables = Question.where('status = 0').where('needs_edits is null and publishable is null').order('created_at ASC').limit(25)
    else
      @posts = Post.requires_moderations(moderator)
      @questions = Question.requires_moderations(moderator)
      @moderatables = (@posts + @questions).sort_by {|m| m.created_at }.reverse
    end

    @engagements, @conversations = [@posts.map{|p|[p.id, p]}, []] #Post.grouped_as_conversations @posts
    @asker = User.find 8765
    @oneinbox = true
    @askers_by_id = Hash[*Asker.select([:id, :twi_screen_name, :twi_profile_img_url]).map{|a| [a.id, {twi_screen_name: a.twi_screen_name, twi_profile_img_url: a.twi_profile_img_url}]}.flatten]
    @asker_twi_screen_names = Asker.askers_with_id_and_twi_screen_name.sort_by! { |a| a.twi_screen_name.downcase }.each { |a| a.twi_screen_name = a.twi_screen_name.downcase }
    @display_notifications = Post.create_split_test(moderator.id, 'grading on mod manage displays actions via growl (mod => regular)', 'false', 'true')
  end

  def create
    moderator = current_user.becomes(Moderator)
    
    if params['post_id']
      moderation = moderator.post_moderations.find_or_initialize_by(post_id: params['post_id'])
      moderation.update_attributes type_id: params['type_id']
      Post.trigger_split_test(moderator.id, 'mod request script (=> moderate answer)')
      response = moderation.reload.post.moderation_trigger_type_id.present? ? moderation.type_id : nil
    elsif params['question_id']
      question = Question.find(params['question_id'])
      previous_consensus = (question.needs_edits == true or question.publishable == true)
      moderation = moderator.question_moderations.find_or_create_by(question_id: params['question_id'], type_id: params['type_id'])
      response = (moderator.is_admin? or (previous_consensus and moderator.is_question_super_mod? and (moderation.type_id != 7)))
    end
    render json: response
  end
end