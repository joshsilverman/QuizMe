class Moderation < ActiveRecord::Base
  attr_accessible :accepted, :post_id, :type_id, :user_id

  belongs_to :post
  belongs_to :moderator, :class_name => 'Moderator', foreign_key: :user_id

  scope :correct, where(type_id: 1)
  scope :incorrect, where(type_id: 2)
  scope :tell, where(type_id: 3)
  # scope :hide, where(type_id: 4)
  scope :ignore, where(type_id: 5)
  scope :requires_detailed, where(type_id: 6)

  scope :accepted, where("accepted = ?", true)
  scope :rejected, where("accepted = ?", false)

  def respond_with_type_id
    return false if !post.correct.nil? or !post.requires_action

    greater_than_one_mod = post.moderations.count > 1
    three_mods = (post.moderations.count == 3)

    complete_consensus = post.moderations.collect(&:type_id).uniq.count == 1
    partial_consensus = (three_mods and (post.moderations.collect(&:type_id).uniq.count == 2))
    
    at_least_one_mod_above_noob = post.moderations.select{|m| m.moderator.moderator_segment > 2 if m.moderator.moderator_segment}.count > 0
    at_least_one_mod_above_advanced = post.moderations.select{|m| m.moderator.moderator_segment > 4 if m.moderator.moderator_segment}.count > 0
    at_least_one_consensus_mod_above_noob = (three_mods and partial_consensus and (post.moderations.select { |m| post.moderations.select { |mm| mm.type_id == m.type_id }.count > 1 and m.moderator.moderator_segment and m.moderator.moderator_segment > 2 }.count > 0))
    
    # consensus
  	if greater_than_one_mod and complete_consensus and at_least_one_mod_above_noob
      post.update_attributes moderation_trigger_type_id: 1
  		return type_id
  	elsif at_least_one_mod_above_advanced # supermod
      post.update_attributes moderation_trigger_type_id: 2
  		super_moderation = post.moderations.select{|m| m.moderator.moderator_segment > 4 if m.moderator.moderator_segment}.first
  		return super_moderation.type_id
  	elsif three_mods and partial_consensus and at_least_one_consensus_mod_above_noob
      post.update_attributes moderation_trigger_type_id: 3
      partial_consensus_moderation = post.moderations.select { |m| post.moderations.select { |mm| mm.type_id == m.type_id }.count > 1 and m.moderator.moderator_segment and m.moderator.moderator_segment > 2 }.first
      return partial_consensus_moderation.type_id
    end
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

    # puts "triggering response on post ID #{post.id}"

    if [1,2,3].include? type_id
      if post.interaction_type == 4
        response_post = asker.private_response post, correct, 
          tell: tell,
          in_reply_to_user_id: post.user_id,
          conversation: post.conversation
      else
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
    accept_and_reject_moderations
  end

  def accept_and_reject_moderations
    post.moderations.each do |moderation|
      if type_id == moderation.type_id
        moderation.update_attribute :accepted, true
        next if moderation.moderator.moderations.count > 1
        Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
      else
        moderation.update_attribute :accepted, false
      end
    end
  end
end