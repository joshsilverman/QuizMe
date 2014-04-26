class DataAddCounterCacheToTopics < ActiveRecord::Migration
  def self.up
    add_column :topics, :_question_count, :integer, :default => 0
    
    Topic.all.each do |topic|
      topic.update _question_count: topic.questions.length
    end
  end

  def self.down
    remove_column :topics, :_question_count
  end
end