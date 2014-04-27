class AddQuestionbaseIdToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :questionbase_id, :integer
  end
end
