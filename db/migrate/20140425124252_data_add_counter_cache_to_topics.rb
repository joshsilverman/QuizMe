class DataAddCounterCacheToTopics < ActiveRecord::Migration
  def self.up
    add_column :topics, :questions_count, :integer, :default => 0
    
    Topic.all.each do |topic|
      topic.update questions_count: topic.questions.length
    end
  end

  def self.down
    remove_column :topics, :questions_count
  end
end