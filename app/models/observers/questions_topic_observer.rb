class QuestionsTopicObserver < ActiveRecord::Observer
  def after_save questions_topic
    topic = Topic.find(questions_topic.topic_id)
    topic.update_question_count
  end

  def after_destroy questions_topic
    topic = Topic.find(questions_topic.topic_id)
    topic.update_question_count
  end
end