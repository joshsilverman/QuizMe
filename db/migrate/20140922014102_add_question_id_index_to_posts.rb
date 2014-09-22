class AddQuestionIdIndexToPosts < ActiveRecord::Migration
  def change
    add_index :posts, :question_id
  end
end
