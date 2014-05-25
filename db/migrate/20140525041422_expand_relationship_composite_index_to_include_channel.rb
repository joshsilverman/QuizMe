class ExpandRelationshipCompositeIndexToIncludeChannel < ActiveRecord::Migration
  def up
    remove_index :relationships, [:follower_id, :followed_id]
    add_index :relationships, [:follower_id, :followed_id, :channel], unique: true
  end

  def down
    remove_index :relationships, [:follower_id, :followed_id, :channel]
    add_index :relationships, [:follower_id, :followed_id], unique: true
  end
end
