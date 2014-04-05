class TopicSerializer < ActiveModel::Serializer
  attributes :id, :name, :topic_url

  def topic_url
    object.topic_url
  end
end
