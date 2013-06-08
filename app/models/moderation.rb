class Moderation < ActiveRecord::Base
  attr_accessible :accepted, :post_id, :type_id, :user_id

  belongs_to :user
  belongs_to :post
  belongs_to :moderator, foreign_key: :user_id

  scope :correct, where(type_id: 1)
  scope :incorrect, where(type_id: 2)
  scope :tell, where(type_id: 3)
  # scope :hide, where(type_id: 4)
  scope :ignore, where(type_id: 5)
  scope :requires_detailed, where(type_id: 6)

  def respond_with_type_id
  	greater_than_one_mod = post.moderations.count > 1
  	complete_consensus = post.moderations.collect(&:type_id).uniq.count == 1
  	at_least_one_mod_above_noob = post.moderations.select{|m| m.user.moderator_segment > 2}.count > 0
  	at_least_one_mod_above_advanced = post.moderations.select{|m| m.user.moderator_segment > 4}.count > 0

  	# early consensus
  	if greater_than_one_mod and complete_consensus and at_least_one_mod_above_noob
  		return type_id
  	# supermod
  	elsif at_least_one_mod_above_advanced
  		super_moderation = post.moderations.select{|m| m.user.moderator_segment > 4}.first
  		return super_moderation.type_id
  	end

  	# tie-breaker
  	# if 3 moderations
  		# if consensus on 2
  		# if consensus group contains mod with segment > 3
  			# return consensus group type id
  end

  def trigger_response
    case type_id
    when 1
      correct = true
    when 2
      correct = false
    when 3
      correct = false
      tell = true
    when 5
      post.update_attribute :requires_action, false
    when 6
    end

    root_post = post.conversation.post
    asker = post.in_reply_to_user.becomes Asker

    if [1,2,3].include? type_id
      asker.app_response(post, correct, {
        :link_to_parent => root_post.is_question_post? ? false : true,
        :tell => tell,
        :conversation_id => post.conversation.id,
        :post_to_twitter => true,
        :manager_response => true,
        :quote_user_answer => root_post.is_question_post? ? true : false,
        :intention => 'grade'
      })
    end
  end

  def accept_and_reject_moderations
    post.moderations.each do |moderation|
      if type_id == moderation.type_id
        moderation.update_attribute :accepted, true
        next if moderation.user.moderations.count > 1
        Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
      else
        moderation.update_attribute :accepted, false
      end
    end
  end
end