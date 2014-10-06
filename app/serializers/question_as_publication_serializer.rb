class QuestionAsPublicationSerializer < ActiveModel::Serializer
  attributes :question_id, :asker_id, :_answers, :_question, :_asker, :_lesson, :created_at

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
      correct_answer_id: object._correct_answer_id,
      author_twi_screen_name: object.user.try(:twi_screen_name),
      created_at: object.created_at
    }
  end

  def _lesson
    if @options[:lesson]
      @options[:lesson].attributes
    end
  end

  def _asker
    {
      id: object.created_for_asker_id
    }
  end
end
