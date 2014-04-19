class AddColumnQuestionbaseIdToAnswers < ActiveRecord::Migration
  def change
    add_column :answers, :questionbase_id, :integer
  end
end
