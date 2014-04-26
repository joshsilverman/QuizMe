class QuestionsTopicObserver < ActiveRecord::Observer
  def after_save questions_topic
    update_question_count questions_topic
  end

  def after_destroy questions_topic
    update_question_count questions_topic
  end

  def update_question_count questions_topic
    topic = Topic.find(questions_topic.topic_id)
    question_count = topic.questions.approved.count
    topic.update _question_count: question_count
  end
end