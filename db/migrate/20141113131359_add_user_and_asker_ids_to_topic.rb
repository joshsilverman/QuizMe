class AddUserAndAskerIdsToTopic < ActiveRecord::Migration
  def change
    add_column :topics, :user_id, :integer
    add_column :topics, :asker_id, :integer
  end
end
