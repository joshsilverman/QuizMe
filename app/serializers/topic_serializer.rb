class TopicSerializer < ActiveModel::Serializer
  attributes :id, :name, :topic_url, :_question_count, :user_id, :published

  def topic_url
    object.topic_url
  end
end
