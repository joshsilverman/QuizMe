class AddQuestionModerationAttributesToQuestions < ActiveRecord::Migration
  def change
  	add_column :questions, :publishable, :boolean
  	add_column :questions, :inaccurate, :boolean
  	add_column :questions, :ungrammatical, :boolean
  	add_column :questions, :bad_answers, :boolean
  	add_column :questions, :moderation_trigger_type_id, :integer
  end
end
