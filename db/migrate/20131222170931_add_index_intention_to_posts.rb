class AddIndexIntentionToPosts < ActiveRecord::Migration
  def change
    add_index :posts, :intention
  end
end
