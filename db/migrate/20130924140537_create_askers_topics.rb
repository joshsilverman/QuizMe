class CreateAskersTopics < ActiveRecord::Migration
  def change
    create_table :askers_topics do |t|
      t.integer :asker_id
      t.integer :topic_id
    end
    
    Askertopic.all.each do |askertopic|
      next if Asker.where(id: asker_id).empty?

      Asker.find(askertopic.asker_id).topics << Topic.find(askertopic.topic_id)
    end
  end	
end
