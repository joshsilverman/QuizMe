class AddLastFollowbackFailureColumnToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_followback_failure, :datetime
  end
end
