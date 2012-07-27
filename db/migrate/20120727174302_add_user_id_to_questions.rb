class AddUserIdToQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :user_id, :integer
    add_column :questions, :status, :integer, :default => 0
  end
end
