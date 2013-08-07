class QuestionModeration < Moderation
	default_scope -> { where('question_id is not null') }
	belongs_to :question

	scope :publishable, -> { where(type_id: 7) }
	scope :inaccurate, -> { where(type_id: 8) }
	scope :ungrammatical, -> { where(type_id: 9) }
	scope :bad_answers, -> { where(type_id: 10) }
  scope :needs_edits, -> { where(type_id: 11) }

  scope :active, -> { where(active: true) }

	def respond_with_type_id
    # return false if question.status != 0

    greater_than_two_moderators = question.question_moderations.active.collect(&:user_id).uniq.count > 2
    agreement_on_type_id = question.question_moderations.active.select { |qm| qm.type_id == type_id }.count > 2
    previous_consensus = (!question.publishable.nil? or !question.needs_edits.nil?)

    if previous_consensus and moderator.is_question_super_mod?
      question.clear_feedback
      question.update(moderation_trigger_type_id: 2, status: (type_id == 7 ? 1 : -1))
      accept_and_reject_moderations
      return type_id
    elsif greater_than_two_moderators and agreement_on_type_id
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
    when 11
      attribute = :needs_edits
    end
    question.update(attribute => true)
  end	

  def accept_and_reject_moderations
    question.question_moderations.each { |m| m.update(accepted: (type_id == m.type_id)) }
  end  
end