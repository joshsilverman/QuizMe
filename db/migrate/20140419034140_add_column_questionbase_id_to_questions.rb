class AddColumnQuestionbaseIdToQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :questionbase_id, :integer
  end
end
