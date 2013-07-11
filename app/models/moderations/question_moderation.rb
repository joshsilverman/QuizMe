class QuestionModeration < Moderation
	default_scope where('question_id is not null')
	belongs_to :question

	scope :publishable, where(type_id: 7)
	scope :inaccurate, where(type_id: 8)
	scope :ungrammatical, where(type_id: 9)
	scope :bad_answers, where(type_id: 10)

	def respond_with_type_id
    return false if question.status != 0

    greater_than_one_moderator = question.question_moderations.collect(&:user_id).uniq.count > 1
    agreement_on_type_id = question.question_moderations.select { |qm| qm.type_id == type_id  }.count > 1
    three_mods = question.question_moderations.collect(&:user_id).uniq.count == 3
    
    if greater_than_one_moderator and agreement_on_type_id
      question.update_attributes moderation_trigger_type_id: 1
      return type_id
    elsif three_mods and agreement_on_type_id
      question.update_attributes moderation_trigger_type_id: 3
      return type_id
    end
	end

  def trigger_response
    case type_id
    when 7
      attribute = :publishable
    when 8
      attribute = :inaccurate
    when 9
      attribute = :ungrammatical
    when 10
    	attribute = :bad_answers
    end

    question.update_attribute(attribute, true)
  end	

  # def accept_and_reject_moderations
  #   post.post_moderations.each do |moderation|
  #     if type_id == moderation.type_id
  #       moderation.update_attribute :accepted, true
  #       next if moderation.moderator.post_moderations.count > 1
  #       Post.trigger_split_test(moderation.user_id, "show moderator q & a or answer (-> accepted grade)")
  #     else
  #       moderation.update_attribute :accepted, false
  #     end
  #   end
  # end  
end