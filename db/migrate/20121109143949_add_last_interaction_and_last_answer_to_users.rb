class AddLastInteractionAndLastAnswerToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_interaction_at, :datetime
    add_column :users, :last_answer_at, :datetime  
  end
end
