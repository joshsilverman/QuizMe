class AddQuestionIdToModerations < ActiveRecord::Migration
  def change
    add_column :moderations, :question_id, :integer
  end
end
