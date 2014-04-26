class TopicSerializer < ActiveModel::Serializer
  attributes :id, :name, :topic_url, :_question_count
end
