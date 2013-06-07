class AddModeratorSegmentToUsers < ActiveRecord::Migration
  def change
    add_column :users, :moderator_segment, :integer
  end
end
