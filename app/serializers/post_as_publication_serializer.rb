class PostAsPublicationSerializer < ActiveModel::Serializer
  attributes :question_id, :asker_id, :_answers, :_question, :_asker

  def asker_id
    object.user_id
  end

  def _question
    return nil if object.question.nil?

    {
      id: object.question.id,
      text: object.question.text,
      correct_answer_id: object.question._correct_answer_id
    }
  end

  def _answers
    ret = {}
    return ret if object.question.nil?

    object.question.answers.each do |answer|
      ret[answer.id.to_s] = answer.text
    end

    ret
  end

  def _asker
    {
      id: object.user_id
    } 
  end
end