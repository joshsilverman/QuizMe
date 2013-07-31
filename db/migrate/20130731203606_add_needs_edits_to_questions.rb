class AddNeedsEditsToQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :needs_edits, :boolean
  end
end
