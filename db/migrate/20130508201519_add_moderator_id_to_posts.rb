class AddModeratorIdToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :moderator_id, :integer
  end
end
