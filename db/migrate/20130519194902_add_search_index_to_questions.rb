class AddSearchIndexToQuestions < ActiveRecord::Migration
  def change
  	add_index :questions, :text
  end
end
