class AddIsReengagementToPosts < ActiveRecord::Migration
  def up
    add_column :posts, :is_reengagement, :boolean, default: false
    Post.reengage_inactive.each { |p| p.update(is_reengagement: true) }
  end

  def down
  	remove_column :posts, :is_reengagement
  end
end
