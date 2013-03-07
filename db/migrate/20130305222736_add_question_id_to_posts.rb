class AddQuestionIdToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :question_id, :integer
  end
end
