class QuestionModeration < Moderation
	default_scope where('question_id is not null')
	belongs_to :question

	scope :publishable, where(type_id: 7)
	scope :innacurate, where(type_id: 8)
	scope :grammar, where(type_id: 9)

	def respond_with_type_id
    return false if question.status != 0

    greater_than_one_mod = question.question_moderations.count > 1
    three_mods = (question.question_moderations.count == 3)

    complete_consensus = question.question_moderations.collect(&:type_id).uniq.count == 1
    partial_consensus = (three_mods and (question.question_moderations.collect(&:type_id).uniq.count == 2))
    
    at_least_one_mod_above_noob = question.question_moderations.select{|m| m.moderator.moderator_segment > 2 if m.moderator.moderator_segment}.count > 0
    at_least_one_mod_above_advanced = question.question_moderations.select{|m| m.moderator.moderator_segment > 4 if m.moderator.moderator_segment}.count > 0
    at_least_one_consensus_mod_above_noob = (three_mods and partial_consensus and (question.question_moderations.select { |m| question.question_moderations.select { |mm| mm.type_id == m.type_id }.count > 1 and m.moderator.moderator_segment and m.moderator.moderator_segment > 2 }.count > 0))
    
    # consensus
  	if greater_than_one_mod and complete_consensus and at_least_one_mod_above_noob
      question.update_attributes moderation_trigger_type_id: 1
  		return type_id
  	elsif at_least_one_mod_above_advanced # supermod
      question.update_attributes moderation_trigger_type_id: 2
  		super_moderation = question.question_moderations.select{|m| m.moderator.moderator_segment > 4 if m.moderator.moderator_segment}.first
  		return super_moderation.type_id
  	elsif three_mods and partial_consensus and at_least_one_consensus_mod_above_noob
      question.update_attributes moderation_trigger_type_id: 3
      partial_consensus_moderation = question.question_moderations.select { |m| question.question_moderations.select { |mm| mm.type_id == m.type_id }.count > 1 and m.moderator.moderator_segment and m.moderator.moderator_segment > 2 }.first
      return partial_consensus_moderation.type_id
    end		
	end
end