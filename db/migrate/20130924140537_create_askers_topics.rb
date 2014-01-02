class CreateAskersTopics < ActiveRecord::Migration
  def change
    create_table :askers_topics do |t|
      t.integer :asker_id
      t.integer :topic_id
    end
  end	
end
