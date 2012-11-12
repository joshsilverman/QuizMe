class AddLearnerLevelToUsers < ActiveRecord::Migration
  def change
    add_column :users, :learner_level, :string, :default => "unengaged"
  end
end
