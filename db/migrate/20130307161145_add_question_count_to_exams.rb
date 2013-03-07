class AddQuestionCountToExams < ActiveRecord::Migration
  def change
    add_column :exams, :question_count, :integer
    add_column :exams, :price, :decimal, :precision => 8, :scale => 2
  end
end
