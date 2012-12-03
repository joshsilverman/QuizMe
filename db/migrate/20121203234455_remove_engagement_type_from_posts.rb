class RemoveEngagementTypeFromPosts < ActiveRecord::Migration
  def up
  	remove_column :posts, :engagement_type
  end

  def down
  	add_column :posts, :engagement_type, :string
  end
end
