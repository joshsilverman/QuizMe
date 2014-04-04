class AddCorrectAnswerIdToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :_correct_answer_id, :integer
  end
end
