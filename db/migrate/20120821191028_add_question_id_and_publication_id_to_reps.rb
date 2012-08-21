class AddQuestionIdAndPublicationIdToReps < ActiveRecord::Migration
  def change
  	add_column :reps, :question_id, :integer
  	add_column :reps, :publication_id, :integer
  end
end
