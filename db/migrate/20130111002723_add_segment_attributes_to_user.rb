class AddSegmentAttributesToUser < ActiveRecord::Migration
  def change
  	add_column :users, :lifecycle_segment, :integer
  	add_column :users, :activity_segment, :integer
  	add_column :users, :interaction_segment, :integer
  	add_column :users, :author_segment, :integer
  end
end
