class QuestionAsPublicationSerializer < ActiveModel::Serializer
  attributes :question_id, :asker_id, :_answers, :_question, :_asker, :created_at

  def question_id
    object.id
  end

  def asker_id
    object.created_for_asker_id
  end

  def _question
    {
      id: object.id,
      text: object.text,
      correct_answer_id: object._correct_answer_id
    }
  end

  def _asker
    {
      id: object.created_for_asker_id
    }
  end
end
